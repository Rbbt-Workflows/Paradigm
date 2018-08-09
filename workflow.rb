require 'rbbt-util'
require 'rbbt/workflow'

Misc.add_libdir if __FILE__ == $0

#require 'rbbt/sources/Paradigm'

module Paradigm
  extend Workflow


  Rbbt.claim Rbbt.root.modules.Paradigm.paradigm, :proc do 
    Misc.in_dir Rbbt.root.modules.Paradigm.find do
      Log.debug CMD.cmd('make')
    end
  end


  helper :save_obs_file do |content, name, entities|
    f = file('run').obs[name].find + '.tab'
    Misc.sensiblewrite(f, content.to_s)

    l = Open.read(f).split("\n").reject{|l| l =~ /^#:/ }
    l.first.sub!(/^#/,'')
    file_entities = l.first.split("\t")[1..-1]
    entity_pos = [0] + entities.collect{|e| file_entities.index(e) }.compact.collect{|p| p + 1 }

    samples = []
    io = TSV.traverse l, :type => :array, :into => :stream do |line|
      res = []
      line.split("\t").each_with_index{|e,i| res <<  e if entity_pos.include?(i) }
      samples << res.first
      res * "\t"
    end
    Open.write(f, io)

    samples.shift


    samples
  end

  helper :select_obs_samples do |name, samples|
    f = file('run').obs[name].find + '.tab'

    header = true

    io = TSV.traverse Open.open(f), :into => :stream, :type => :array do |line|
      if header
        header = false
      else
        sample = line.partition("\t").first
        next unless samples.include?(sample)
      end

      line
    end

    Misc.sensiblewrite(f, io)
  end


  input :pathway, :text, "Pathway definition", nil, :required => true
  input :genome, :text, "Genome observations"
  input :mRNA, :text, "Expression observations"
  input :protein, :text, "Protein abundance observations"
  input :activity, :text, "Protein activity observations"
  input :disc, :array, "Discretization breakpoints", [-1.3, 1.3]
  input :inference, :string, "Inference method", "method=BP,updates=SEQFIX,tol=1e-9,maxiter=10000,logdomain=0,verbose=1"
  input :max_degree, :integer, "Max degree for the graph", 7
  input :config_paradigm, :text, "Config file for Paradigm (overrides default)"
  task :analysis => :text do |pathway, genome, mRNA, protein, activity, disc, inference, max_degree, config_override|

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

    params_file = run_dir["params.txt"].find
    config << "pathway [max_in_degree=#{max_degree},param_file=#{params_file}]" << "\n"

    config << "em [max_iters=0,log_z_tol=0.01]" << "\n"
    config << "em_step [#{obs_type.collect{|type| type + '.tab=-obs>'} * ","}]" << "\n"
    config_file = run_dir.config

    config = config_override if config_override and not config_override.empty?
    Open.write(config_file, config)

    Misc.in_dir run_dir.find do
      Paradigm.run(pathway_file, config_file, run_dir.obs + "/", true)
    end
  end
end

#require 'Paradigm/tasks/basic.rb'

#require 'rbbt/knowledge_base/Paradigm'
#require 'rbbt/entity/Paradigm'

