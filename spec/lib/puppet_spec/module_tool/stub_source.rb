module PuppetSpec
  module ModuleTool
    class StubSource < Semantic::Dependency::Source
      def host
        "http://nowhe.re"
      end

      def fetch(name)
        available_releases[name.tr('/', '-')].values
      end

      def available_releases
        return @available_releases if defined? @available_releases

        @available_releases = {
          'puppetlabs-java' => {
            '10.0.0' => { 'puppetlabs/stdlib' => '4.1.0' },
          },
          'puppetlabs-stdlib' => {
            '4.1.0' => {},
          },
          'pmtacceptance-stdlib' => {
            "4.1.0" => {},
            "3.2.0" => {},
            "3.1.0" => {},
            "3.0.0" => {},
            "2.6.0" => {},
            "2.5.1" => {},
            "2.5.0" => {},
            "2.4.0" => {},
            "2.3.2" => {},
            "2.3.1" => {},
            "2.3.0" => {},
            "2.2.1" => {},
            "2.2.0" => {},
            "2.1.3" => {},
            "2.0.0" => {},
            "1.1.0" => {},
            "1.0.0" => {},
          },
          'pmtacceptance-keystone' => {
            '3.0.0-rc2' => { "pmtacceptance/mysql" => ">=0.6.1 <1.0.0", "pmtacceptance/stdlib" => ">= 2.5.0" },
            '3.0.0-rc1' => { "pmtacceptance/mysql" => ">=0.6.1 <1.0.0", "pmtacceptance/stdlib" => ">= 2.5.0" },
            '2.2.0'     => { "pmtacceptance/mysql" => ">=0.6.1 <1.0.0", "pmtacceptance/stdlib" => ">= 2.5.0" },
            '2.2.0-rc1' => { "pmtacceptance/mysql" => ">=0.6.1 <1.0.0", "pmtacceptance/stdlib" => ">= 2.5.0" },
            '2.1.0'     => { "pmtacceptance/mysql" => ">=0.6.1 <1.0.0", "pmtacceptance/stdlib" => ">= 2.5.0" },
            '2.0.0'     => { "pmtacceptance/mysql" => ">= 0.6.1" },
            '1.2.0'     => { "pmtacceptance/mysql" => ">= 0.5.0" },
            '1.1.1'     => { "pmtacceptance/mysql" => ">= 0.5.0" },
            '1.1.0'     => { "pmtacceptance/mysql" => ">= 0.5.0" },
            '1.0.1'     => { "pmtacceptance/mysql" => ">= 0.5.0" },
            '1.0.0'     => { "pmtacceptance/mysql" => ">= 0.5.0" },
            '0.2.0'     => { "pmtacceptance/mysql" => ">= 0.5.0" },
            '0.1.0'     => { "pmtacceptance/mysql" => ">= 0.3.0" },
          },
          'pmtacceptance-mysql' => {
            "2.1.0"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "2.0.1"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "2.0.0"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "2.0.0-rc5" => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "2.0.0-rc4" => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "2.0.0-rc3" => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "2.0.0-rc2" => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "2.0.0-rc1" => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "1.0.0"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.9.0"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.8.1"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.8.0"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.7.1"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.7.0"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.6.1"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.6.0"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.5.0"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.4.0"     => {},
            "0.3.0"     => {},
            "0.2.0"     => {},
          },
          'pmtacceptance-apache' => {
            "0.10.0"    => { "pmtacceptance/stdlib" => ">= 2.4.0" },
            "0.9.0"     => { "pmtacceptance/stdlib" => ">= 2.4.0" },
            "0.8.1"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.8.0"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.7.0"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.6.0"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.5.0-rc1" => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.4.0"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.3.0"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.2.2"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.2.1"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.2.0"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.1.1"     => { "pmtacceptance/stdlib" => ">= 2.2.1" },
            "0.0.4"     => {},
            "0.0.3"     => {},
            "0.0.2"     => {},
            "0.0.1"     => {},
          },
          'pmtacceptance-bacula' => {
            "0.0.3" => { "pmtacceptance/stdlib" => ">= 2.2.0", "pmtacceptance/mysql" => ">= 1.0.0" },
            "0.0.2" => { "pmtacceptance/stdlib" => ">= 2.2.0", "pmtacceptance/mysql" => ">= 0.0.1" },
            "0.0.1" => { "pmtacceptance/stdlib" => ">= 2.2.0" },
          },
        }

        @available_releases.each do |name, versions|
          versions.each do |version, deps|
            constraints = Hash[deps.map { |k, v| [ k.tr('/', '-'), v ] }]

            versions[version] = create_release(name, version, constraints).tap do |release|
              release.meta_def(:prepare)     { }
              release.meta_def(:install)     { |x| @install_dir = x.to_s }
              release.meta_def(:install_dir) { @install_dir }
              release.meta_def(:metadata) do
                {
                  :name         => name,
                  :version      => version,
                  :source       => '',   # GRR, Puppet!
                  :author       => '',   # GRR, Puppet!
                  :license      => '',   # GRR, Puppet!
                  :dependencies => constraints.map do |dep, range|
                    { :name => dep, :version_requirement => range }
                  end
                }
              end
            end
          end
        end
      end
    end
  end
end
