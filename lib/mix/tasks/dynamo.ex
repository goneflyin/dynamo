defmodule Mix.Tasks.Dynamo do
  use Mix.Task

  import Mix.Generator
  import Mix.Utils, only: [camelize: 1, underscore: 1]

  @version Dynamo.Mixfile.project[:version]
  @shortdoc "Create a new Dynamo project"

  @moduledoc """
  Creates a new Dynamo project.
  It expects the path of the project as argument.

      mix dynamo [-v] PATH [--app APP] [--module MODULE]

  A project at the given PATH  will be created. The
  application name and module name will be retrieved
  from the path, unless `-app` or `--module` is given.

  ## Examples

      mix dynamo hello_world

  Is equivalent to:

      mix dynamo hello_world --app hello_world --module HelloWorld

  Use -v to print mix version:

      mix dynamo -v

  """
  def run(["-v"]) do
    Mix.shell.info "Dynamo v#{@version}"
  end

  def run(argv) do
    { opts, argv } = OptionParser.parse(argv, flags: [:dev])
    case argv do
      [] ->
        raise Mix.Error, message: "expected PATH to be given, please use `mix dynamo PATH`"
      [path|_] ->
        name = opts[:app] || File.basename(File.expand_path(path))
        check_project_name!(name)
        File.mkdir_p!(path)
        File.cd!(path, fn -> do_generate(underscore(name), opts) end)
    end
  end

  defp do_generate(app, opts) do
    mod     = opts[:module] || camelize(app)
    dynamo  = if opts[:dev] do
      %b(raw: "#{File.expand_path("../../../..", __FILE__)}")
    else
      %b(git: "https://github.com/josevalim/dynamo.git")
    end
    assigns = [app: app, mod: mod, dynamo: dynamo, version: @version]

    create_file "README.md",  readme_template(assigns)
    create_file ".gitignore", gitignore_text
    create_file "mix.exs",    mixfile_template(assigns)

    create_directory "app"
    create_directory "app/routers"
    create_file "app/routers/application_router.ex", app_router_template(assigns)

    create_directory "config"
    create_file "config/app.ex", config_app_template(assigns)

    create_directory "config/environments"
    create_file "config/environments/dev.exs",  config_dev_template(assigns)
    create_file "config/environments/test.exs", config_test_template(assigns)
    create_file "config/environments/prod.exs", config_prod_template(assigns)

    create_directory "lib"
    create_directory "public"
  end

  defp check_project_name!(name) do
    unless name =~ %r/^[a-z][\w_]+$/i do
      raise Mix.Error, message: "project path must start with a letter and have only letters, numbers and underscore"
    end
  end

   embed_template :readme, """
   # <%= @mod %>

   ** TODO: Add description **
   """

   embed_text :gitignore, """
   /ebin
   /deps
   erl_crash.dump
   """

  embed_template :mixfile, """
  defmodule <%= @mod %>.Mixfile do
    use Mix.Project

    def project do
      [ app: :<%= @app %>,
        version: "0.0.1",
        compilers: [:elixir, :dynamo, :app],
        deps: deps ]
    end

    # Configuration for the OTP application
    def application do
      []
    end

    defp deps do
      [ { :mimetypes, git: "https://github.com/spawngrid/mimetypes.git" },
        { :cowboy, "0.6.1", git: "https://github.com/josevalim/cowboy.git" },
        { :dynamo, "<%= @version %>", <%= @dynamo %> } ]
    end
  end
  """

  embed_template :app_router, """
  defmodule ApplicationRouter do
    use Dynamo.Router

    # Pick which parts of the request you want to fetch
    # You can comment the line below if you don't need
    # any of them or move them to a forwarded router
    fetch [:cookies, :params]

    # It is common to break your application in many
    # routers forwarding the requests between them
    # forward "/posts", to: PostsRouter

    get "/" do
      conn.resp(200, "Hello world")
    end
  end
  """

  embed_template :config_app, """
  defmodule <%= @mod %> do
    use Dynamo.App

    endpoint ApplicationRouter

    config :dynamo,
      # The OTP application associated to this app
      # This is the name of the .app file generated by mix
      otp_app: :<%= @app %>,
      # The route from where public assets are served
      # You can turn off static assets by setting it to false
      public_route: "/public"
  end
  """

  embed_template :config_dev, """
  config :dynamo,
    # Compile modules as they are accessed.
    # This makes development easy as we don't
    # need to explicitly compile files.
    compile_on_demand: true,

    # Every time a module in app changes, we
    # will clean up defined modules and pick
    # up the latest versions.
    reload_modules: true
  """

  embed_template :config_test, """
  config :dynamo,
    # For testing we compile modules on demand,
    # but there isn't a need to reload them.
    compile_on_demand: true,
    reload_modules: false
  """

  embed_template :config_prod, """
  config :dynamo,
    # On production, modules are compiled up-front.
    compile_on_demand: false,
    reload_modules: false
  """
end