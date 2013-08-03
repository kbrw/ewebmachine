# Ewebmachine #

Ewebmachine is a very simple Elixir DSL around Webmachine
from basho :
https://github.com/basho/webmachine

## Ewebmachine modules ##

Resources module are grouped into a module which has to use
Ewebmachine.

    defmodule MyApp1 do
      use Ewebmachine

      resource ['hello',:name] do
        to_html do:
          """
          <html>
            <body>
              <h1> Hello #{:wrq.path_info(:name,_req)} </h1>
            </body>
          </html>
          """
      end

Each "resource" declares a webmachine resource module. The
resource takes the route as a parameter, so that 
MyApp1.routes returns the list of webmachine dispatch rules
corresponding to the resources declared in MyApp1.

## Default Supervisor ##

Ewebmachine.Sup is a default supervisor for web application, it
launches mochiweb configured to use webmachine with the following
configuration :

* *listen ip* : environment variable {:ewebmachine, :ip} or "0.0.0.0"
* *listen port* : environment variable {:ewebmachine, :port} or 7272
* *log_dir* : environment variable {:ewebmachine, :port} or "priv/log"
* *dispatch* :
  environment variable {:ewebmachine, :routes} lists the
  ewebmachine module routes to be include

## Default Application ##

Ewebmachine.App is a default OTP application for web application,
it launches only the default supervisor Ewebmachine.Sup.

## Initial State ##

An initial state (which is used in webmachine "init" function)
can be declared with `ini`.

    resource [] do
      ini [:init]
    end

## Webmachine debug mode ##

The trace mode is activated for every resources when executed in
Mix *dev* environment. Traces are stored in directory defined by
`{:webmachine,:trace_dir}` if defined, else in `/tmp`.

Default Application add the `/debug` route to access the
webmachine traces in *dev* environment.

## Resource Functions ##

Resource functions can be declared directly by name,
body-producing function must start with `to_*` or
`from_*`. Every resource functions are declared without
ReqData and Context parameters declaration, which are implicitly
declared as variable `\_req` and `_ctx`.

The resource functions response is wrap so that you can omit
context and reqdata if they did not change.

So for instance, the following resource functions are equivalent :

    resource_exists, do: true
 
    resource_exists, do: {true,_req,_ctx}

## Example usage ##

Declare two ewebmachine module : 


    defmodule WebMain do
      use Ewebmachine

      resource [] do
        to_html, do: "<html><body>Hello world</body>"
      end

      resource['sitemap'] do
        content_types_provided, do: ['application/xml': to_xml]
        to_xml do
          """
          <?xml version="1.0" encoding="UTF-8"?>
          <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
          <url>
              <loc>http://mon-domaine.fr/</loc>
              <lastmod>2012-12-15</lastmod>
              <changefreq>daily</changefreq>
              <priority>1</priority>
          </url>
          </urlset>
          """
        end
      end
    end

    defmodule WebContact do
      use Ewebmachine

      resource ['contact'] do
        to_html, do: "<html><body>contact page</body>"
      end
    end


Then create an OTP application that launches mochiweb with the
webmain and webcontact routes :

    def application do
      [ mod: { Ewebmachine.App,[] },
        applications: [:webmachine],
        env: [ip: '0.0.0.0',
              port: 7171,
              routes: [WebMain,WebContact]] ]
    end

