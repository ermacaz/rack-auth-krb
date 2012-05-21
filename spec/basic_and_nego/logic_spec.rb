require 'spec_helper'
require 'basic_and_nego/logic'
require 'basic_and_nego/nulllogger'

describe BasicAndNego::Logic do
  it "should not re-authenticate user" do
    env = {}
    env['rack.session'] = {}
    env['rack.session']['REMOTE_USER'] = 'fred'
    a = BasicAndNego::Logic.new(env, BasicAndNego::NullLogger.new, 'my realm', 'my keytab file')
    a.process_request
    a.response.should be_nil
    a.headers.should be_empty
  end

  it "should try to authenticate if there's no session" do
    env = {}
    a = BasicAndNego::Logic.new(env, BasicAndNego::NullLogger.new, 'my realm', 'my keytab file')
    a.should_receive(:authenticate)
    a.process_request
  end

  it "should set REMOTE_USER if user authenticated" do
    env = {}
    a = BasicAndNego::Logic.new(env, BasicAndNego::NullLogger.new, 'my realm', 'my keytab file')
    a.should_receive(:authenticate).and_return(true)
    a.should_receive(:client_name).and_return("fred")
    a.process_request
    env['REMOTE_USER'].should == "fred"
  end

  it "should update the session if user authenticated" do
    env = {}
    env['rack.session'] = {}
    a = BasicAndNego::Logic.new(env, BasicAndNego::NullLogger.new, 'my realm', 'my keytab file')
    a.should_receive(:authenticate).and_return(true)
    a.should_receive(:client_name).twice.and_return("fred")
    a.process_request
    env['REMOTE_USER'].should == "fred"
    env['rack.session']['REMOTE_USER'].should == 'fred'
  end

  it "should try to authenticate if user is not yet authenticated" do
    env = {}
    env['rack.session'] = {}
    a = BasicAndNego::Logic.new(env, BasicAndNego::NullLogger.new, 'my realm', 'my keytab file')
    a.should_receive(:authenticate)
    a.process_request
  end

  it "should ask for an authorization key if none is provided" do
    env = {}
    env['rack.session'] = {}
    a = BasicAndNego::Logic.new(env, BasicAndNego::NullLogger.new, 'my realm', 'my keytab file')
    a.authenticate
    a.response.should_not be_nil
    a.response[0].should == 401
  end
  describe "GSS authentication" do 
    it "should try authentication against GSS in case of Negotiate" do
      env = {'HTTP_AUTHORIZATION' => "Negotiate ffggg"}
      env['rack.session'] = {}
      a = BasicAndNego::Logic.new(env, BasicAndNego::NullLogger.new, 'my realm', 'my keytab file')
      gss = double('gss').as_null_object
      gss.should_receive(:authenticate).and_return(true)
      BasicAndNego::GSS.should_receive(:new).and_return(gss)
      a.authenticate
    end

    it "should return 'unauthorized' if authentication fails" do 
      env = {'HTTP_AUTHORIZATION' => "Negotiate ffggg"}
      env['rack.session'] = {}
      a = BasicAndNego::Logic.new(env, BasicAndNego::NullLogger.new, 'my realm', 'my keytab file')
      gss = double('gss').as_null_object
      gss.should_receive(:authenticate).and_return(false)
      BasicAndNego::GSS.should_receive(:new).and_return(gss)
      a.authenticate.should be_false
      a.response.should_not be_nil
      a.response[0].should == 401

    end

    it "should return true if authentication worked" do
      env = {'HTTP_AUTHORIZATION' => "Negotiate ffggg"}
      env['rack.session'] = {}
      a = BasicAndNego::Logic.new(env, BasicAndNego::NullLogger.new, 'my realm', 'my keytab file')
      gss = double('gss').as_null_object
      gss.should_receive(:authenticate).and_return(true)
      BasicAndNego::GSS.should_receive(:new).and_return(gss)
      a.authenticate.should be_true
      a.response.should be_nil
    end

    it "should set client's name if authentication worked" do
      env = {'HTTP_AUTHORIZATION' => "Negotiate ffggg"}
      env['rack.session'] = {}
      a = BasicAndNego::Logic.new(env, BasicAndNego::NullLogger.new, 'my realm', 'my keytab file')
      gss = double('gss').as_null_object
      gss.should_receive(:authenticate).and_return(true)
      gss.should_receive(:display_name).and_return("fred")
      BasicAndNego::GSS.should_receive(:new).and_return(gss)
      a.authenticate.should be_true
      a.client_name.should == "fred"
    end

  end

  describe "Kerberos authentication" do
    it "should try authentication against Kerberos in case of Basic" do
      env = {'HTTP_AUTHORIZATION' => "Basic #{Base64.encode64('fred:pass')}"}
      env['rack.session'] = {}
      realm = "my realm"
      keytab = "my keytab"
      a = BasicAndNego::Logic.new(env, BasicAndNego::NullLogger.new, realm, keytab)
      krb = double('kerberos').as_null_object
      krb.should_receive(:authenticate).with("fred", "pass").and_return(true)
      BasicAndNego::Krb.should_receive(:new).with(realm, keytab).and_return(krb)
      a.authenticate
    end
  end
end