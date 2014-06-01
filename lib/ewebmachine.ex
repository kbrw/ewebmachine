defmodule Ewebmachine do
  defmacro __before_compile__(_env) do
    quote do
      def routes, do: @routes |> Enum.reverse
    end
  end
  defmacro __using__(_opts) do
    quote do
      import Ewebmachine
      @before_compile Ewebmachine
      @routes []
    end
  end
  defmacro ini(ini_ctx) do
    quote do 
      @ctx unquote(ini_ctx)
    end
  end
  defmacro resource(route,[do: code]) do
    quote do
      modulename = "#{__MODULE__}#{@routes|>length}" |> binary_to_atom
      defmodule modulename do
        @ctx nil
        unquote(wm_wrap(code))
        def ping(rq,s), do: {:pong,rq,s}
        def init([]), do: {unquote(Mix.env==:dev && {:trace,:application.get_env(:ewebmachine,:trace_dir,'/tmp')}||:ok),@ctx||[]}
        defp wrap_reponse({:dictstate,r,newstate},rq,state), do: {r,rq,Keyword.merge(state,newstate)}
        defp wrap_reponse({_,_,_}=tuple,_,_), do: tuple
        defp wrap_reponse(r,rq,state), do: {r,rq,state}
        defp pass(r,update_state), do: {:dictstate,r,update_state}
      end
      @routes [{unquote(route),modulename,[]}|@routes]
    end
  end

  defp wm_fun(name), do:
    name in [:resource_exists,:service_available,:is_authorized,:forbidden,:allow_missing_post,:malformed_request,
        :base_uri,:uri_too_long,:known_content_type,:valid_content_headers,:valid_entity_length,:options,:allowed_methods,
        :delete_resource,:delete_completed,:post_is_create,:create_path,:process_post,:content_types_provided,
        :content_types_accepted,:charsets_provided,:encodings_provided,:variances,:is_conflict,:multiple_choices,
        :previously_existed,:moved_permanently,:moved_temporarily,:last_modified,:expires,:generate_etag,:finish_request]
  defp wm_format_conv("to_"<>_), do: true
  defp wm_format_conv("from_"<>_), do: true
  defp wm_format_conv(_), do: false

  defp wm_wrap({:__block__,meta,blocks}),do: 
    {:__block__,meta,Enum.map(blocks,&wm_wrap(&1))}
  defp wm_wrap({name,_,[[do: code]]}=block) do
    if wm_fun(name) or wm_format_conv(atom_to_binary(name)) do
      quote do
        def unquote(name)(unquote({:_req,[],nil}),unquote({:_ctx,[],nil})) do
          (
             unquote(code)
          )|>
          wrap_reponse(unquote({:_req,[],nil}),unquote({:_ctx,[],nil}))
        end
      end
    else
        block
    end
  end
  defp wm_wrap(code),do: code

  defmodule Sup do
    use Supervisor.Behaviour
    def start_link(conf), do: :supervisor.start_link(__MODULE__,conf)
    def name_of(conf), do: :"wm_#{inspect conf[:ip]}_#{conf[:port]}"
    def init(conf) do
      defaultconf = [dispatch_group: name_of(conf), name: name_of(conf), ip: '0.0.0.0',port: 8080, log_dir: 'priv/log', 
         dispatch: List.flatten(Enum.map(conf[:modules], fn m->m.routes end))]
      supervise([
        worker(:webmachine_mochiweb,[defaultconf |> Keyword.merge(Keyword.delete(conf,:modules))], function: :start),
        worker(__MODULE__,[], restart: :temporary, function: :set_debug)
      ], strategy: :one_for_one)
    end

    def set_debug do
      {:ok,Process.spawn_link(fn -> 
        unquote(if Mix.env==:dev do quote do 
          :wmtrace_resource.add_dispatch_rule('debug',:application.get_env(:ewebmachine,:trace_dir,'/tmp'))
        end end)
      end)}
    end
  end
end
