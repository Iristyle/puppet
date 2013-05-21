require 'puppet/util/license'
require 'date'
require 'rational'

def make_me_a_fake_ca(nodes = [])
  all_nodes = ['ca'] + Array(nodes)

  ca = double()
  ca.should_receive(:list){all_nodes}.once
  nodes.each do |node|
    ca.should_receive(:verify).with(node).once
  end
  Puppet::SSL::CertificateAuthority.stub(:new){ ca }.once

  Puppet::SSL::CertificateAuthority.should_receive(:ca?){ true }.once
end

def make_me_a_fake_license(content)
  YAML.should_receive(:load_file).with(Puppet::Util::License::LicenseKey) {
    YAML.load(content)
  }.once
end

describe Puppet::Util::License do
  # The number of free licenses may change.  It already has from 2 to 10 And
  # this spec test never got updated.  When the free license count increases
  # again in the future, simply change it here.
  let(:free_licenses) { 10 }

  describe "#valid_license_date" do
    it "returns true if date is nil" do
      Puppet::Util::License.valid_license_date(nil).should == true
    end

    it "returns true if the date is a Date instance" do
      Puppet::Util::License.valid_license_date(Date.today).should == true
    end

    ["foo", 12, 1.23].each do |item|
      it "should return false when given a #{item.class.name}" do
        Puppet::Util::License.valid_license_date(item).should == false
      end
    end
  end

  describe "display_license_status when not a CA" do
    it "should return false when we are not a CA" do
      Puppet::SSL::CertificateAuthority.should_receive(:ca?) { false }
      Puppet::Util::License.display_license_status.should == false
    end
  end

  describe "display_license_status when we are a CA" do

    describe "invalid license file" do

      # Now, ensure we say we are a CA...
      before :each do
        Puppet::SSL::CertificateAuthority.should_receive(:ca?){ true }.once
      end

      it "should complain and return true when the license file is invalid YAML" do
        # Environment.
        make_me_a_fake_license "{ invalidly formatted yaml here, my friend )"

        # Expected behaviours.
        Puppet.should_receive(:crit).once.
          with(/Your License is incorrectly formatted or corrupted/).
          with(/syntax error on line \d+, col \d+:/)

        # Invocation.
        Puppet::Util::License.display_license_status.should == true
      end

      ["start", "end"].each do |w|
        ["string", "12 may 2011", "20211-14-12", "01/12/2011"].each do |d|
          it "should complain when the #{w} date is invalid: '#{d}'" do

            # Environment.
            make_me_a_fake_license "#{w}: #{d}\n"

            # Expected behaviours.
            Puppet.should_receive(:crit).once.
              with(/Your License is incorrectly formatted or corrupted/).
              with(/The #{w} value .* is improper/)

            # Invocation
            Puppet::Util::License.display_license_status.should == true
          end
        end
      end

      ["foo", "infinity", -2, -1, 0, 1.5, Rational(2,3), [1], {1=>1}].each do |n|
        it "should complain when the node count is invalid: '#{n.inspect}'" do
          make_me_a_fake_license "nodes: #{n.inspect}\n"

          # Expected behaviours.
          Puppet.should_receive(:crit).once.
            with(/Your License is incorrectly formatted or corrupted/).
            with(/The node count .* is improper/)

          # Invocation
          Puppet::Util::License.display_license_status.should == true
        end
      end
    end

    describe "display_license_status with no license file (complimentary license)" do

      before :each do
        YAML.should_receive(:load_file).with(Puppet::Util::License::LicenseKey) {
          raise Errno::ENOENT, "file not found"
        }.once
      end

      it "should be happy when there are no nodes other than the CA" do
        make_me_a_fake_ca

        Puppet.stub :notice
        Puppet.should_receive(:notice).with(/You have no active and no inactive nodes./)
        Puppet.should_receive(:notice).with(/You are currently licensed for #{free_licenses} active nodes./)
        Puppet.should_receive(:notice).with(/complimentary license does not include Support & Maintenance/)

        # Invocation
        Puppet::Util::License.display_license_status.should == true
      end

      it "should work when there are exactly the free node limit of nodes in the CA" do
        make_me_a_fake_ca 1.upto(free_licenses).collect { |i| "node%s" % i }

        Puppet.stub :notice
        Puppet.should_receive(:notice).with(/You have #{free_licenses} active and no inactive nodes./)
        Puppet.should_receive(:notice).with(/You are currently licensed for #{free_licenses} active nodes./)
        Puppet.should_receive(:notice).with(/complimentary license does not include Support & Maintenance/)

        # Invocation
        Puppet::Util::License.display_license_status.should == true
      end

      it "should complain when there are more than the free node limit in the CA" do
        make_me_a_fake_ca 1.upto(free_licenses + 1).collect { |i| "node%s" % i }

        Puppet.stub :alert
        Puppet.should_receive(:alert).with(/You have #{free_licenses + 1} active and no inactive nodes./)
        Puppet.should_receive(:alert).with(/You are currently licensed for #{free_licenses} active nodes/)
        Puppet.should_receive(:alert).with(/You are using a complimentary ten node license/)
        Puppet.should_receive(:alert).with(/have exceeded .* by 1 active node!/)
        Puppet.should_receive(:alert).with(/contact Puppet Labs to obtain additional licenses/)
        Puppet.should_receive(:alert).with(/does not include Support & Maintenance/)

        # Invocation
        Puppet::Util::License.display_license_status.should == true
      end
    end

    describe "display_license_status with a custom license" do

      before :each do
        make_me_a_fake_ca
      end

      { 1 => 'day', 2 => 'days' }.each_pair do |time, word|
        it "should alert you if your license is #{time} #{word} over (with correct grammar)" do

          date = (Date.today - time).to_s
          make_me_a_fake_license "nodes: 10\nend: #{date}\n"

          Puppet.stub :alert
          Puppet.should_receive(:alert).with(/Your Support & Maintenance agreement expired on #{date}/)
          Puppet.should_receive(:alert).with(/You have run for #{time} #{word} without a support agreement/)
          Puppet.should_receive(:alert).with(/You can reach Puppet Labs for sales, support, or maintenance agreements/)

          Puppet::Util::License.display_license_status.should == true
        end
      end

      { 1 => 'day', 2 => 'days', 29 => 'days', 30 => 'days' }.each_pair do |time, word|
        it "should alert when #{time} #{word} are left in your support agreement (with correct grammer)" do

          date = (Date.today + time).to_s
          make_me_a_fake_license "nodes: 10\nend: #{date}\n"

          Puppet.stub :warning
          Puppet.should_receive(:warning).with(/Your Support & Maintenance term expires on #{date}/)
          Puppet.should_receive(:warning).with(/You have #{time} #{word} remaining under that agreement;/)
          Puppet.should_receive(:warning).with(/You can reach Puppet Labs for sales, support, or maintenance agreements/)

          Puppet::Util::License.display_license_status.should == true
        end
      end

      it "should not alert me if no end date is specified in the license" do

        make_me_a_fake_license "nodes: 1\n"

        Puppet.stub :notice
        Puppet.should_not_receive(:notice).with(/renew your Support & Maintenance agreement/)

        Puppet::Util::License.display_license_status.should == true
      end

      %w{start end}.each do |word|
        it "should tell me what my #{word} date is" do

          make_me_a_fake_license "nodes: 1\n#{word}: 2020-09-29"

          Puppet.stub :notice
          Puppet.should_receive(:notice).with(/Your support and maintenance agreement #{word}s on 2020-09-29/)

          Puppet::Util::License.display_license_status.should == true
        end
      end

      it "should tell me who the license is licensed to" do

        make_me_a_fake_license "nodes: 10\nto: zaphod\n"

        Puppet.stub :notice
        Puppet.should_receive(:notice).with(/This Puppet Enterprise distribution is licensed to:/)
        Puppet.should_receive(:notice).with(/zaphod/)

        Puppet::Util::License.display_license_status.should == true
      end

      it "should not tell me I have a complimentary license" do

        make_me_a_fake_license "nodes: 1\nto: zaphod\n"

        Puppet.stub :notice
        Puppet.should_not_receive(:notice).with(/Your complimentary license/)

        Puppet::Util::License.display_license_status.should == true
      end

    end
  end
end
