load File.expand_path('../tasks/host.rake', __FILE__)
Dir.glob(File.expand_path('../tasks/components/*.rake', __FILE__)).each { |r| load r }
