require 'rbbt-util'
require 'rbbt/resource'

module Paradigm
  extend Resource
  self.subdir = 'share/databases/Paradigm'

  #def self.organism(org="Hsa")
  #  Organism.default_code(org)
  #end

  #self.search_paths = {}
  #self.search_paths[:default] = :lib

  Rbbt.claim Rbbt.software.opt.libdai, :install, Rbbt.share.install.software.libdai.find
  Rbbt.claim Rbbt.software.opt.Paradigm, :install, Rbbt.share.install.software.Paradigm.find

end

iif Rbbt.software.opt.libdai.produce.find if __FILE__ == $0
iif Rbbt.software.opt.Paradigm.produce.find if __FILE__ == $0

