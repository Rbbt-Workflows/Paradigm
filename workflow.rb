require 'rbbt-util'
require 'rbbt/workflow'

Misc.add_libdir if __FILE__ == $0

#require 'rbbt/sources/Paradigm'

module Paradigm
  extend Workflow

  COMMAND = Rbbt.root.modules.Paradigm.paradigm.find

  def self.run(pathway, config, params = nil, prefix = nil)
    opts = {"-p" => pathway, "-c" => config, "-b" => prefix}
    opts["-t"] = params if params
    CMD.cmd(COMMAND,opts)
  end

  helper :save_obs_file do |content, name, entities|
    f = file('run').obs[name].find + '.tab'
    Open.write(f, content.to_s)

    TmpFile.with_file do |tmp|
      CMD.cmd("grep -v '^#:' '#{f}' | sed 's/^#//' > #{tmp}")
      file_entities = Open.read(tmp).split("\n").first.split("\t")[1..-1]
      entity_pos = [1] + entities.collect{|e| file_entities.index(e)}.compact.collect{|p| p + 2}
      CMD.cmd("cut -f #{entity_pos*","}  #{ tmp } > #{f}")
    end
    samples = CMD.cmd("cut -f 1 #{f}").read.split("\n")[1..-1].uniq

    samples
  end

  helper :select_obs_samples do |name, samples|
    f = file('run').obs[name].find + '.tab'
    TmpFile.with_file do |stmp|
      TmpFile.with_file do |ftmp|
        Open.write(stmp, samples * "\n")
        CMD.cmd("head -n 1 '#{f}'  > #{ftmp}")
        CMD.cmd("grep -F -w -f '#{stmp}' '#{f}' |sort  >> #{ftmp}")
        FileUtils.mv ftmp, f
      end
    end
  end


  input :pathway, :text, "Pathway definition"
  input :genome, :text, "Genome observations"
  input :mRNA, :text, "Expression observations"
  input :protein, :text, "Protein abundance observations"
  input :activity, :text, "Protein activity observations"
  input :disc, :array, "Discretization breakpoints", [-1.3, 1.3]
  input :inference, :string, "Inference method", "method=BP,updates=SEQFIX,tol=1e-9,maxiter=10000,logdomain=0,verbose=1"
  input :params, :text, "Parameter file"
  input :config, :text, "Config file (overrides default)"
  task :analysis => :text do |pathway, genome, mRNA, protein, activity, disc, inference, params, config_override|

    run_dir = file('run').find

    pathway_file = run_dir.pathway
    Open.write(pathway_file, pathway)
    lines = Open.read(pathway_file).split("\n").collect{|l| l.split("\t") }.select{|v| v.length == 2}
    entities = lines.collect{|v| v.last }

    obs_type = []
    config = "inference [#{inference}]" << "\n"

    samples = []

    if genome
      s = save_obs_file(genome, 'genome', entities)
      samples << s
      obs_type << "genome"
    end

    if mRNA
      s = save_obs_file(mRNA, 'mRNA', entities)
      samples << s
      obs_type << "mRNA"
    end

    if protein
      s = save_obs_file(protein, 'protein', entities)
      samples << s
      obs_type << "protein"
    end

    if activity
      s = save_obs_file(activity, 'activity', entities)
      samples << s
      obs_type << "activity"
    end

    num_obs = obs_type.length
    good_samples = Misc.counts(samples.flatten).select{|s,c| c == num_obs}.keys

    disc_str = disc.collect{|d| d.to_s } * ";"
    obs_type.each do |type|
      select_obs_samples(type, good_samples)
      config << "evidence [suffix=#{type}.tab,node=#{type},disc=#{disc_str},epsilon=0.01,epsilon0=0.2]" << "\n"
    end

    if params
      param_file = run_dir.params
      Open.write(param_file, params)
      config << "pathway [max_in_degree=5,param_file=#{param_file}]" << "\n"
    else
      param_file = nil
    end

    config << "em [max_iters=0,log_z_tol=0.01]" << "\n"
    config << "em_step [#{obs_type.collect{|type| type + '.tab=-obs>'} * ","}]" << "\n"

    config_file = run_dir.config

    config = config_override if config_override and not config_override.empty?
    Open.write(config_file, config)

    Misc.in_dir run_dir.find do
      Paradigm.run(pathway_file, config_file, nil, run_dir.obs + "/")
    end
  end
end

#require 'Paradigm/tasks/basic.rb'

#require 'rbbt/knowledge_base/Paradigm'
#require 'rbbt/entity/Paradigm'

