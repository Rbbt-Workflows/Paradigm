require 'rbbt-util'
require 'rbbt/workflow'

Misc.add_libdir if __FILE__ == $0

#require 'rbbt/sources/Paradigm'

module Paradigm
  extend Workflow

  COMMAND = Rbbt.root.modules.Paradigm.paradigm.find

  def self.run(pathway, config, prefix)
    CMD.cmd(COMMAND,"-p" => pathway, "-c" => config, "-b" => prefix)
  end

  input :pathway, :text, "Pathway definition"
  input :genome, :text, "Genome observations"
  input :mRNA, :text, "Expression observations"
  input :protein, :text, "Protein abundance observations"
  input :activity, :text, "Protein activity observations"
  task :analysis => :text do |pathway, genome, mRNA, protein, activity|

    run_dir = file('run').find

    pathway_file = run_dir.pathway
    Open.write(pathway_file, pathway)

    obs_type = []
    config =<<-EOF
inference [method=JTREE,updates=HUGIN,verbose=1]
em [max_iters=0,log_z_tol=0.01]
    EOF

    if genome
      genome_file = run_dir.obs.genome + '.tab'
      Open.write(genome_file, genome)
      obs_type << "genome"
      config << "evidence [suffix=genome.tab,node=genome,disc=-1.3;1.3,epsilon=0.01,epsilon0=0.2]" << "\n"
    end

    if mRNA
      mRNA_file = run_dir.obs.mRNA + '.tab'
      Open.write(mRNA_file, mRNA)
      obs_type << "mRNA"
      config << "evidence [suffix=mRNA.tab,node=mRNA,disc=-1.3;1.3,epsilon=0.01,epsilon0=0.2]" << "\n"
    end

    if protein
      protein_file = run_dir.obs.protein + '.tab'
      Open.write(protein_file, protein)
      obs_type << "protein"
      config << "evidence [suffix=protein.tab,node=protein,disc=-1.3;1.3,epsilon=0.01,epsilon0=0.2]" << "\n"
    end

    if activity
      activity_file = run_dir.obs.activity + '.tab'
      Open.write(activity_file, activity)
      obs_type << "activity"
      config << "evidence [suffix=activity.tab,node=activity,disc=-1.3;1.3,epsilon=0.01,epsilon0=0.2]" << "\n"
    end

    config << "em_step [#{obs_type.collect{|type| type + '.tab=-obs>'} * ","}]"

    config_file = run_dir.config
    Open.write(config_file, config)

    Misc.in_dir run_dir.find do
      Paradigm.run(pathway_file, config_file, "obs/")
    end
  end


end

#require 'Paradigm/tasks/basic.rb'

#require 'rbbt/knowledge_base/Paradigm'
#require 'rbbt/entity/Paradigm'

