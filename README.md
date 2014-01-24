# Ewebmachine #

Ewebmachine is a very simple Elixir DSL around Webmachine
from basho :
https://github.com/basho/webmachine

## Ewebmachine modules ##

Resources module are grouped into a module which has to use
Ewebmachine.

```elixir
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
```

Each "resource" declares a webmachine resource module. The
resource takes the route as a parameter, so that 
MyApp1.routes returns the list of webmachine dispatch rules
corresponding to the resources declared in MyApp1.

## Default Supervisor ##

Ewebmachine.Sup is a default supervisor for web application, it
launches mochiweb configured to use webmachine with the following
configuration options (`start_link` dictlist parameter):

* *listen ip* : default to "0.0.0.0"
* *listen port* : default to 7272
* *log_dir* : default to "priv/log"
* *dispatch* : lists the ewebmachine module routes to be include, mandatory

## Default Application ##

Ewebmachine.App is a default OTP application for web application,
it launches only the default supervisor Ewebmachine.Sup, with parameters defined
by the ewebmachine application environment.

## Initial State ##

An initial state (which is used in webmachine "init" function)
can be declared with `ini`, the default one is a list (because of the resource
        function response shortut described below)

```elixir
resource [] do
  ini [:init]
end
```

## Webmachine debug mode ##

The trace mode is activated for every resources when executed in
Mix *dev* environment. Traces are stored in directory defined by
`{:webmachine,:trace_dir}` if defined, else in `/tmp`.

Default Supervisor add the `/debug` route to access the
webmachine traces in *dev* environment.

## Resource Functions ##

Resource functions can be declared directly by name,
body-producing function must start with `to_*` or
`from_*`. Every resource functions are declared without
ReqData and Context parameters declaration, which are implicitly
declared as variable `\_req` and `_ctx`.

###  Resource functions response shortcuts ###

The resource functions response is wrap so that you replace the standard
{res,req,ctx} webmachine response by :

* `res` is a shortcut to `{res,_req,_ctx}`
* `pass(res, opt1: value1, opt2: value2)` is a shortcut to
  `{res,_req,updated_ctx}` where `updated_ctx` is the listdict merge between
  old listdict state and keywords arguments (opt1,opt2 here), works only if
  `_ctx` is a dictlist

So for instance, the following resource functions are equivalent :

```elixir
resource_exists, do: true
resource_exists, do: {true,_req,_ctx}
```

And you can transmit some variable in the context like this :

```elixir
resource ['user',:name] do
  resource_exists do
     user = User.get(:wrq.path_info(:name,_req))
     pass user != nil, user: user
  end
  to_html do: (_ctx[:user] |> template("user_template"))
end
```

## Example usage ##

Declare two ewebmachine module : 

```elixir
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
```

Then create an OTP application that launches mochiweb with the
webmain and webcontact routes :

```elixir
def application do
  [ mod: { Ewebmachine.App,[] },
    applications: [:webmachine],
    env: [ip: '0.0.0.0',
          port: 7171,
          routes: [WebMain,WebContact]] ]
end
```
