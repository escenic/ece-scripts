define escenic::engine(
  $type = $default_engine_type,
  $search_host = "localhost",
  $conf_archive_uri)
{
  $common_content="
technet_user=$technet_user
technet_password=$technet_password

fai_${type}_conf_archive=$conf_archive_uri
fai_${type}_ear=$ear_uri
fai_${type}_install=1
fai_${type}_search_host=${search_host}
fai_db_host=$db_host
fai_db_password=$db_password
fai_db_schema=$db_schema
fai_db_user=$db_user
fai_keep_off_etc_hosts=1
fai_monitoring_server_ip=$monitoring_server_ip
"
  $editor_content="
# editor specific
"
  $presentation_content="
# presentation specific
"

  file { "/root/ece-install-$name.conf":
    content =>  $type ? {
      editor => "$common_content $editor_content",
      presentation => "$common_content $presentation_content",
      default => "# you specific a non existant profile: $type",
    }
  }
}
