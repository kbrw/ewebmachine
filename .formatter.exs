locals_without_parens = [
  resource: 4,
  resource: 3,
  defh: 2,
  pass: 2,

  # Handlers
  allowed_methods: 1,
  allow_missing_post: 1,
  base_uri: 1,
  charsets_provided: 1,
  content_types_accepted: 1,
  content_types_provided: 1,
  create_path: 1,
  delete_completed: 1,
  delete_resource: 1,
  encodings_provided: 1,
  expires: 1,
  forbidden: 1,
  generate_etag: 1,
  is_authorized: 1,
  is_conflict: 1,
  known_content_type: 1,
  known_methods: 1,
  language_available: 1,
  last_modified: 1,
  malformed_request: 1,
  moved_permanently: 1,
  moved_temporarily: 1,
  multiple_choices: 1,
  options: 1,
  ping: 1,
  post_is_create: 1,
  previously_existed: 1,
  process_post: 1,
  resource_exists: 1,
  service_available: 1,
  uri_too_long: 1,
  validate_content_checksum: 1,
  valid_content_headers: 1,
  valid_entity_length: 1,
  variances: 1
]

[
  import_deps: [
    :plug
  ],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens ++ [decision: 2],
  export: [locals_without_parens: locals_without_parens]
]
