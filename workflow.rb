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

  COMMAND = Rbbt.root.modules.Paradigm.paradigm.produce.find(:lib)

  def self.run(pathway, config, prefix)
    CMD.cmd(COMMAND,"-p" => pathway, "-c" => config, "-b" => prefix)
  end

  helper :clean_text do |text,components|
    out = ""
    if TSV === text
      lines = Misc.sort_stream(text.dumper_stream).read.split("\n")
    else
      lines = text.split("\n")
    end
    fields = nil
    pos = nil
    while line = lines.shift
      next if line =~ /#:/
      line.sub!(/^#[^\t]+/,'id') if line[0] == "#"
      parts = line.split "\t"
      if pos.nil?
        pos = [0] + components.to_a[1..-1].collect{|c| parts.index c}.compact
      end

      line = parts.values_at(*pos) * "\t"

      out << line << "\n"
    end
    out
  end

  input :pathway, :text, "Pathway definition"
  input :genome, :text, "Genome observations"
  input :mRNA, :text, "Expression observations"
  input :protein, :text, "Protein abundance observations"
  input :activity, :text, "Protein activity observations"
  input :discretization, :array, "Discretization points", [-1.3, 1.3] # [0.5] [-0.5,0.5]
  input :samples, :array, "Samples to consider"
  task :analysis => :text do |pathway, genome, mRNA, protein, activity, discretization,samples|

    run_dir = file('run').find

    pathway_file = run_dir.pathway
    Open.write(pathway_file, pathway)
    components = Set.new
    TSV.traverse pathway_file, :type => :array, :into => components do |line|
      parts = line.split "\t"
      next if parts.length != 2
      parts.last
    end

    obs_type = []
    disc = discretization.collect{|v| v.to_s} * ";"

    config = ""

    #config << "inference [method=JTREE,updates=HUGIN,verbose=1]"
    
    config << "inference [method=BP,inference=SUMPROD,updates=SEQMAX,logdomain=0,tol=1e-9,maxiter=10000,damping=0.0]" << "\n"

    config << "em [max_iters=0,log_z_tol=0.01]" << "\n"

    file_headers = {}

    if genome
      genome_file = run_dir.obs.genome + '.tab'
      Open.write(genome_file, clean_text(genome, components))
      obs_type << "genome"
      config << "evidence [suffix=genome.tab,node=genome,disc=#{disc},epsilon=0.01,epsilon0=0.2]" << "\n"
      file_headers[genome_file] = CMD.cmd("cut -f 1 '#{genome_file}'").read.split("\n")
    end

    if mRNA
      mRNA_file = run_dir.obs.mRNA + '.tab'
      Open.write(mRNA_file, clean_text(mRNA, components))
      obs_type << "mRNA"
      config << "evidence [suffix=mRNA.tab,node=mRNA,disc=#{disc},epsilon=0.01,epsilon0=0.2]" << "\n"
      file_headers[mRNA_file] = CMD.cmd("cut -f 1 '#{mRNA_file}'").read.split("\n")
    end

    if protein
      protein_file = run_dir.obs.protein + '.tab'
      Open.write(protein_file, clean_text(protein, components))
      obs_type << "protein"
      config << "evidence [suffix=protein.tab,node=protein,disc=#{disc},epsilon=0.01,epsilon0=0.2]" << "\n"
      file_headers[protein_file] = CMD.cmd("cut -f 1 '#{protein_file}'").read.split("\n")
    end

    if activity
      activity_file = run_dir.obs.activity + '.tab'
      Open.write(activity_file, clean_text(activity, components))
      obs_type << "activity"
      config << "evidence [suffix=activity.tab,node=activity,disc=#{disc},epsilon=0.01,epsilon0=0.2]" << "\n"
      file_headers[activity_file] = CMD.cmd("cut -f 1 '#{activity_file}'").read.split("\n")
    end

    num_files = file_headers.keys.size
    good_headers = Misc.counts(file_headers.values.flatten).select{|h,c| c == num_files}.collect{|h,c| h}
    good_headers &= samples if samples and samples.any?
    file_headers.each do |file,headers|
      TmpFile.with_file do |tmp|
        Open.write(tmp + '.headers', ([headers.first] + good_headers).collect{|h| "^#{h}\t"} *"\n")
        CMD.cmd("grep -f '#{tmp + '.headers'}' '#{file}' > #{ tmp }")
        FileUtils.mv tmp, file
      end
    end



    config << "em_step [#{obs_type.collect{|type| type + '.tab=-obs>'} * ","}]"

    config_file = run_dir.config
    Open.write(config_file, config)

    Misc.in_dir run_dir.find do
      Log.debug "Running with config:" << "\n" << Open.read(config_file) << "\n"
      Paradigm.run(pathway_file, config_file, "obs/")
    end
  end


end

#require 'Paradigm/tasks/basic.rb'

#require 'rbbt/knowledge_base/Paradigm'
#require 'rbbt/entity/Paradigm'

