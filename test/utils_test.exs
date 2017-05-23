Code.require_file "test_helper.exs", __DIR__

defmodule Ewebmachine.Core.UtilsTest do
  use ExUnit.Case
  import Ewebmachine.Core.Utils

  test "Content Type negotiation found a value" do
    for accept_header<-["*", "*/*", "text/*", "text/html"] do
      assert {"text","html",%{}} == choose_media_type([{"text","html",%{}}],accept_header)
    end
  end

  test "Content Type negotiation no matching value" do
    for accept_header<-["foo", "text/xml", "application/*", "foo/bar/baz"] do
      assert nil == choose_media_type([{"text","html",%{}}], accept_header)
    end
  end

  test "Content Type negotiation quality selection" do
    provided = [{"text","html",%{}},{"image","jpeg",%{}}]
    for accept_header<-["image/jpeg;q=0.5, text/html",
                        "text/html, image/jpeg; q=0.5",
                        "text/*; q=0.8, image/*;q=0.7",
                        "text/*;q=.8, image/*;q=.7"] do
      assert {"text","html",%{}} == choose_media_type(provided,accept_header)
    end
    for accept_header<-["image/*;q=1, text/html;q=0.9",
                        "image/png, image/*;q=0.3"] do
      assert {"image","jpeg",%{}} == choose_media_type(provided,accept_header)
    end
  end

  test "rfc1123 date conversion" do
    assert "Thu, 11 Jul 2013 04:33:19 GMT" == rfc1123_date({{2013, 7, 11}, {4, 33, 19}})
  end

  test "rfc1123 date parsing" do
    assert {{2009,12,30},{14,39,2}} == convert_request_date("Wed, 30 Dec 2009 14:39:02 GMT")
    assert :bad_date == convert_request_date(:toto)
  end

  test "content type normalization roundtrip" do
    for type<-["audio/vnd.wave; codec=31",
             "text/x-okie; charset=iso-8859-1; declaration=f950118.AEB0com"] do
      assert type == (type |> normalize_mtype |> format_mtype)
    end
    assert "audio/vnd.wave; codec=31" == format_mtype({"audio","vnd.wave",%{codec: "31"}})
  end
end
