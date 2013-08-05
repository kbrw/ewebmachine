defmodule MyApp1 do
  use Ewebmachine
  
  resource [] do
    content_types_provided do: [{'application/json',:to_json},{'text/html',:to_html}]
    to_json do:
      """
      {
        "Hello World":"http://localhost:7171/hello/world",
        "Hello Arnaud":"http://localhost:7171/hello/arnaud",
        "Hello Bonhomme":"http://localhost:7171/hello/bonhomme"
      }
      """
    to_html do:
      """
      <html>
        <body>
          <h1>Menu</h1>
          <ul>
            <li><a href="/hello/world">Hello World</a></li>
            <li><a href="/hello/arnaud">Hello Arnaud</a></li>
            <li><a href="/hello/bonhomme">Hello Bonhomme</a></li>
          </ul>
        </body>
      </html>
      """
  end

  resource ['hello',:name] do
    content_types_provided do: [{'application/json',:to_json},{'text/html',:to_html}]
    to_json do: 
      """
      {
        "coucou": "true",
        "lala": "lolo",
        "name": "#{name(_req)}"
      }
      """
    to_html do: 
      """
      <html>
        <body>
          <h1>Hello #{name(_req)}</h1>
        </body>
      </html>
      """
      def name(req), do: :wrq.path_info(:name,req)
  end

end
