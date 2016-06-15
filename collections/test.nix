# [["nokogiri"], ["mechanize"], ["mysql2"]]
{build_ruby_package, fix, fetchurl}: fix (rpkgs: {
"pkg-config-1.1.7" = build_ruby_package rpkgs {"src" = fetchurl {"url" = "http://production.cf.rubygems.org/gems/pkg-config-1.1.7.gem"; "md5" = "2767d4620b32f2a4ccddc18c353e5385";}; "name" = "pkg-config"; "version" = "1.1.7"; "dependencies" = [];};
"pkg-config" = rpkgs."pkg-config-1.1.7";
"mini_portile2-2.1.0" = build_ruby_package rpkgs {"src" = fetchurl {"url" = "http://production.cf.rubygems.org/gems/mini_portile2-2.1.0.gem"; "md5" = "d771975a58cef82daa6b0ee03522293f";}; "name" = "mini_portile2"; "version" = "2.1.0"; "dependencies" = [];};
"mini_portile2" = rpkgs."mini_portile2-2.1.0";
"nokogiri-1.6.8" = build_ruby_package rpkgs {"src" = fetchurl {"url" = "http://production.cf.rubygems.org/gems/nokogiri-1.6.8.gem"; "md5" = "51402a536f389bfcef0ff1600b8acff5";}; "name" = "nokogiri"; "version" = "1.6.8"; "dependencies" = ["mini_portile2" "pkg-config"];};
"nokogiri" = rpkgs."nokogiri-1.6.8";
"webrobots-0.1.2" = build_ruby_package rpkgs {"src" = fetchurl {"url" = "http://production.cf.rubygems.org/gems/webrobots-0.1.2.gem"; "md5" = "e0e6e7b467b8adfbd459c58f4d053b49";}; "name" = "webrobots"; "version" = "0.1.2"; "dependencies" = [];};
"webrobots" = rpkgs."webrobots-0.1.2";
"ntlm-http-0.1.1" = build_ruby_package rpkgs {"src" = fetchurl {"url" = "http://production.cf.rubygems.org/gems/ntlm-http-0.1.1.gem"; "md5" = "b505e299b6d4a34d54d57b0b24134be2";}; "name" = "ntlm-http"; "version" = "0.1.1"; "dependencies" = [];};
"ntlm-http" = rpkgs."ntlm-http-0.1.1";
"net-http-persistent-2.9.4" = build_ruby_package rpkgs {"src" = fetchurl {"url" = "http://production.cf.rubygems.org/gems/net-http-persistent-2.9.4.gem"; "md5" = "61cb21cccc85ddca77ee58af25bcf51f";}; "name" = "net-http-persistent"; "version" = "2.9.4"; "dependencies" = [];};
"net-http-persistent" = rpkgs."net-http-persistent-2.9.4";
"net-http-digest_auth-1.4" = build_ruby_package rpkgs {"src" = fetchurl {"url" = "http://production.cf.rubygems.org/gems/net-http-digest_auth-1.4.gem"; "md5" = "ebad32b9ca084122546b7893c2d8f8e7";}; "name" = "net-http-digest_auth"; "version" = "1.4"; "dependencies" = [];};
"net-http-digest_auth" = rpkgs."net-http-digest_auth-1.4";
"mime-types-2.99.2" = build_ruby_package rpkgs {"src" = fetchurl {"url" = "http://production.cf.rubygems.org/gems/mime-types-2.99.2.gem"; "md5" = "619cc01658515fbd15797a7f72b5dea5";}; "name" = "mime-types"; "version" = "2.99.2"; "dependencies" = [];};
"mime-types" = rpkgs."mime-types-2.99.2";
"unf_ext-0.0.7.2" = build_ruby_package rpkgs {"src" = fetchurl {"url" = "http://production.cf.rubygems.org/gems/unf_ext-0.0.7.2.gem"; "md5" = "88cf9fe1fa51c12ddc4645e4546c3492";}; "name" = "unf_ext"; "version" = "0.0.7.2"; "dependencies" = [];};
"unf_ext" = rpkgs."unf_ext-0.0.7.2";
"unf-0.1.4" = build_ruby_package rpkgs {"src" = fetchurl {"url" = "http://production.cf.rubygems.org/gems/unf-0.1.4.gem"; "md5" = "64009f92a131c50bc1a932dc50d562c6";}; "name" = "unf"; "version" = "0.1.4"; "dependencies" = ["unf_ext"];};
"unf" = rpkgs."unf-0.1.4";
"domain_name-0.5.20160310" = build_ruby_package rpkgs {"src" = fetchurl {"url" = "http://production.cf.rubygems.org/gems/domain_name-0.5.20160310.gem"; "md5" = "69f380db3d9b21f898031a7cdaeb3ccb";}; "name" = "domain_name"; "version" = "0.5.20160310"; "dependencies" = ["unf"];};
"domain_name" = rpkgs."domain_name-0.5.20160310";
"http-cookie-1.0.2" = build_ruby_package rpkgs {"src" = fetchurl {"url" = "http://production.cf.rubygems.org/gems/http-cookie-1.0.2.gem"; "md5" = "70529d56540a162f52ce361a389a0307";}; "name" = "http-cookie"; "version" = "1.0.2"; "dependencies" = ["domain_name"];};
"http-cookie" = rpkgs."http-cookie-1.0.2";
"mechanize-2.7.4" = build_ruby_package rpkgs {"src" = fetchurl {"url" = "http://production.cf.rubygems.org/gems/mechanize-2.7.4.gem"; "md5" = "48775a28780310480ea218c0a3256338";}; "name" = "mechanize"; "version" = "2.7.4"; "dependencies" = ["domain_name" "http-cookie" "mime-types" "net-http-digest_auth" "net-http-persistent" "nokogiri" "ntlm-http" "webrobots"];};
"mechanize" = rpkgs."mechanize-2.7.4";
"mysql2-0.4.4" = build_ruby_package rpkgs {"src" = fetchurl {"url" = "http://production.cf.rubygems.org/gems/mysql2-0.4.4.gem"; "md5" = "6663933bb99ba23958e9e7be7a6846fc";}; "name" = "mysql2"; "version" = "0.4.4"; "dependencies" = [];};
"mysql2" = rpkgs."mysql2-0.4.4";
"websocket-1.2.3" = build_ruby_package rpkgs {"src" = fetchurl {"url" = "http://production.cf.rubygems.org/gems/websocket-1.2.3.gem"; "md5" = "b3f0f459f71831b123a0d8b5f60ab30f";}; "name" = "websocket"; "version" = "1.2.3"; "dependencies" = [];};
"websocket" = rpkgs."websocket-1.2.3";
"rubyzip-1.2.0" = build_ruby_package rpkgs {"src" = fetchurl {"url" = "http://production.cf.rubygems.org/gems/rubyzip-1.2.0.gem"; "md5" = "2aef4aefee574399686427b2bfed86f2";}; "name" = "rubyzip"; "version" = "1.2.0"; "dependencies" = [];};
"rubyzip" = rpkgs."rubyzip-1.2.0";
"ffi-1.9.10" = build_ruby_package rpkgs {"src" = fetchurl {"url" = "http://production.cf.rubygems.org/gems/ffi-1.9.10.gem"; "md5" = "dede6f5db06f699153b5cdf24c0e7b08";}; "name" = "ffi"; "version" = "1.9.10"; "dependencies" = [];};
"ffi" = rpkgs."ffi-1.9.10";
"childprocess-0.5.9" = build_ruby_package rpkgs {"src" = fetchurl {"url" = "http://production.cf.rubygems.org/gems/childprocess-0.5.9.gem"; "md5" = "a5d59a66774fd830eec2ec3f4114e524";}; "name" = "childprocess"; "version" = "0.5.9"; "dependencies" = ["ffi"];};
"childprocess" = rpkgs."childprocess-0.5.9";
})

