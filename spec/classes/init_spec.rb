require 'puppetlabs_spec_helper/module_spec_helper'
require 'spec_helper'

describe 'suitecrm' do

  context 'with defaults for all parameters' do
    it { should contain_class('suitecrm') }
  end

end