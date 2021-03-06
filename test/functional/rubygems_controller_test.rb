require 'test_helper'

class RubygemsControllerTest < ActionController::TestCase
  context "When logged in" do
    setup do
      @user = Factory(:email_confirmed_user)
      sign_in_as(@user)
    end

    context "On GET to show for another user's gem" do
      setup do
        @rubygem = Factory(:rubygem)
        get :show, :id => @rubygem.to_param
      end

      should_respond_with :success
      should_render_template :show
      should_assign_to :rubygem
      should "not render edit link" do
        assert_have_no_selector "a[href='#{edit_rubygem_path(@rubygem)}']"
      end
    end

    context "On GET to show for this user's gem" do
      setup do
        create_gem(@user)
        get :show, :id => @rubygem.to_param
      end

      should_respond_with :success
      should_render_template :show
      should_assign_to :rubygem
      should "render edit link" do
        assert_have_selector "a[href='#{edit_rubygem_path(@rubygem)}']"
      end
    end

    context "On GET to show for a gem that the user is subscribed to" do
      setup do
        @rubygem = Factory(:rubygem)
        Factory(:version, :rubygem => @rubygem)
        Factory(:subscription, :rubygem => @rubygem, :user => @user)
        get :show, :id => @rubygem.to_param
      end

      should_assign_to(:rubygem) { @rubygem }
      should_respond_with :success
      should "have an invisible subscribe link" do
        assert_have_selector "a[style='display:none']", :content => 'Subscribe'
      end
      should "have a visible unsubscribe link" do
        assert_have_selector "a[style='display:block']", :content => 'Unsubscribe'
      end
    end

    context "On GET to show for a gem that the user is not subscribed to" do
      setup do
        @rubygem = Factory(:rubygem)
        Factory(:version, :rubygem => @rubygem)
        get :show, :id => @rubygem.to_param
      end

      should_assign_to(:rubygem) { @rubygem }
      should_respond_with :success
      should "have a visible subscribe link" do
        assert_have_selector "a[style='display:block']", :content => 'Subscribe'
      end
      should "have an invisible unsubscribe link" do
        assert_have_selector "a[style='display:none']", :content => 'Unsubscribe'
      end
    end

    context "On GET to edit for this user's gem" do
      setup do
        create_gem(@user)
        get :edit, :id => @rubygem.to_param
      end

      should_respond_with :success
      should_render_template :edit
      should_assign_to :rubygem
      should "render form" do
        assert_have_selector "form"
        assert_have_selector "input#linkset_code"
        assert_have_selector "input#linkset_docs"
        assert_have_selector "input#linkset_wiki"
        assert_have_selector "input#linkset_mail"
        assert_have_selector "input#linkset_bugs"
        assert_have_selector "input[type='submit']"
      end
    end

    context "On GET to edit for another user's gem" do
      setup do
        @other_user = Factory(:email_confirmed_user)
        create_gem(@other_user)
        get :edit, :id => @rubygem.to_param
      end
      should_respond_with :redirect
      should_assign_to(:linkset) { @linkset }
      should_redirect_to('the homepage') { root_url }
      should_set_the_flash_to "You do not have permission to edit this gem."
    end

    context "On PUT to update for this user's gem that is successful" do
      setup do
        @url = "http://github.com/qrush/gemcutter"
        create_gem(@user)
        put :update, :id => @rubygem.to_param, :linkset => {:code => @url}
      end
      should_respond_with :redirect
      should_redirect_to('the gem') { rubygem_path(@rubygem) }
      should_set_the_flash_to "Gem links updated."
      should_assign_to(:linkset) { @linkset }
      should "update linkset" do
        assert_equal @url, Rubygem.last.linkset.code
      end
    end

    context "On PUT to update for this user's gem that fails" do
      setup do
        create_gem(@user)
        @url = "totally not a url"
        put :update, :id => @rubygem.to_param, :linkset => {:code => @url}
      end
      should_respond_with :success
      should_render_template :edit
      should_assign_to(:linkset) { @linkset }
      should "not update linkset" do
        assert_not_equal @url, Rubygem.last.linkset.code
      end
      should "render error messages" do
        assert_contain /error(s)? prohibited/m
      end
    end
  end

  context "On GET to index with no parameters" do
    setup do
      @gems = (1..3).map do |n|
        gem = Factory(:rubygem, :name => "agem#{n}")
        Factory(:version, :rubygem => gem)
        gem
      end
      Factory(:rubygem, :name => "zeta")
      get :index
    end

    should_respond_with :success
    should_render_template :index
    should_assign_to(:gems) { @gems }
    should "render links" do
      @gems.each do |g|
        assert_contain g.name
        assert_have_selector "a[href='#{rubygem_path(g)}']"
      end
    end
    should "display uppercase A" do
      assert_contain "starting with A"
    end
  end

  context "On GET to index as an atom feed" do
    setup do
      @versions = (1..3).map { |n| Factory(:version, :created_at => n.hours.ago) }
      get :index, :format => "atom"
    end

    should_respond_with :success
    should_assign_to(:versions) { @versions }
    should "render posts with titles and links" do
      @versions.each do |v|
        assert_contain v.to_title
        assert_have_selector "link[href='#{rubygem_url(v.rubygem)}']"
      end
    end
  end

  context "On GET to index with a letter" do
    setup do
      @gems = (1..3).map { |n| Factory(:rubygem, :name => "agem#{n}") }
      @zgem = Factory(:rubygem, :name => "zeta")
      Factory(:version, :rubygem => @zgem)
      get :index, :letter => "z"
    end
    should_respond_with :success
    should_render_template :index
    should_assign_to(:gems) { [@zgem] }
    should "render links" do
      assert_contain @zgem.name
      assert_have_selector "a[href='#{rubygem_path(@zgem)}']"
    end
    should "display uppercase letter" do
      assert_contain "starting with Z"
    end
  end

  context "On GET to index with a bad letter" do
    setup do
      @gems = (1..3).map do |n|
        gem = Factory(:rubygem, :name => "agem#{n}")
        Factory(:version, :rubygem => gem)
        gem
      end
      Factory(:rubygem, :name => "zeta")
      get :index, :letter => "asdf"
    end

    should_respond_with :success
    should_render_template :index
    should_assign_to(:gems) { @gems }
    should "render links" do
      @gems.each do |g|
        assert_contain g.name
        assert_have_selector "a[href='#{rubygem_path(g)}']"
      end
    end
    should "display uppercase A" do
      assert_contain "starting with A"
      assert_not_contain "asdf"
      assert_not_contain "ASDF"
    end
  end

  context "On GET to show" do
    setup do
      @latest_version = Factory(:version)
      @rubygem = @latest_version.rubygem
      get :show, :id => @rubygem.to_param
    end

    should_respond_with :success
    should_render_template :show
    should_assign_to :rubygem
    should_assign_to(:latest_version) { @latest_version }
    should "render info about the gem" do
      assert_contain @rubygem.name
      assert_contain @latest_version.number
      assert_contain @latest_version.built_at.to_date.to_formatted_s(:long)
    end
  end

  context "On GET to show with a gem that has multiple versions" do
    setup do
      @rubygem = Factory(:rubygem)
      @older_version = Factory(:version, :number => "1.0.0", :rubygem => @rubygem)
      @latest_version = Factory(:version, :number => "2.0.0", :rubygem => @rubygem)
      get :show, :id => @rubygem.to_param
    end

    should_respond_with :success
    should_render_template :show
    should_assign_to :rubygem
    should "render info about the gem" do
      assert_contain @rubygem.name
      assert_contain @latest_version.number
      assert_contain @latest_version.built_at.to_date.to_formatted_s(:long)

      assert_contain "Versions"
      assert_contain @rubygem.versions.last.number
      assert_contain @rubygem.versions.last.built_at.to_date.to_formatted_s(:long)
    end
  end

  context "On GET to show for a gem with no versions" do
    setup do
      @rubygem = Factory(:rubygem)
      get :show, :id => @rubygem.to_param
    end
    should_respond_with :success
    should_render_template :show
    should_assign_to :rubygem
    should "render info about the gem" do
      assert_contain "This gem is not currently hosted on Gemcutter."
    end
  end

  context "On GET to show for a gem with both runtime and development dependencies" do
    setup do
      @version = Factory(:version)

      @development = Factory(:development_dependency, :version => @version)
      @runtime     = Factory(:runtime_dependency,     :version => @version)

      get :show, :id => @version.rubygem.to_param
    end

    should_respond_with :success
    should_render_template :show
    should_assign_to(:latest_version) { @version }
    should "show runtime dependencies and development dependencies" do
      assert_contain @runtime.rubygem.name
      assert_contain @development.rubygem.name
    end
  end

  context "When not logged in" do
    context "On GET to show for a gem" do
      setup do
        @rubygem = Factory(:rubygem)
        Factory(:version, :rubygem => @rubygem)
        get :show, :id => @rubygem.to_param
      end

      should_assign_to(:rubygem) { @rubygem }
      should_respond_with :success
      should "have an subscribe link that goes to the sign in page" do
        assert_have_selector "a[href='#{sign_in_path}']"
      end
      should "not have an unsubscribe link" do
        assert_have_no_selector "a#unsubscribe"
      end
    end

    context "On GET to edit" do
      setup do
        @rubygem = Factory(:rubygem)
        get :edit, :id => @rubygem.to_param
      end
      should_respond_with :redirect
      should_redirect_to('the homepage') { root_url }
    end

    context "On PUT to update" do
      setup do
        @rubygem = Factory(:rubygem)
        put :update, :id => @rubygem.to_param, :linkset => {}
      end
      should_respond_with :redirect
      should_redirect_to('the homepage') { root_url }
    end
  end
end
