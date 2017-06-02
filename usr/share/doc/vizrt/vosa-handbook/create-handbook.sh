#! /usr/bin/env bash

# by torstein@escenic.com

handbook_org=vosa-handbook.org
target_dir=$HOME/tmp/$(basename $0 .sh)-$(date --iso)
host_name_list_outside_network="
  amazonaws.com
"
$(which blockdiag >/dev/null) || {
  cat <<EOF
You must have blockdiag installed. On Debian & Ubuntu the package is
called python-blockdiag
EOF
  exit 1
}

DB_VENDOR_AMAZON_RDS=rds
DB_VENDOR_MYSQL=mysql
DB_VENDOR_PERCONA=percona

function run() {
  "$@"
  if [ $? -ne 0 ]; then
    echo "Command [ $@ ] FAILED :-("
    exit 1
  fi
}

function generate_svg_from_blockdiag() {
  run cp -r $(dirname $0)/graphics $target_dir
  
  for el in $target_dir/graphics/*.blockdiag; do
    echo "Generating SVG of $el ..."
    run blockdiag -T SVG $el
  done
}

function set_customer_specific_variables() {
  if [ -r $conf_file  ]; then
    source $conf_file
    host_name_list_outside_network="
      $host_name_list_outside_network
      ${trail_host_name_list_outside_network}
    "
  else
    echo $conf_file " doesn't exist :-("
    exit 1
  fi

  local virtual_host_key_prefix="trail_virtual_host_"
  local first_virtual_host=$(
    set | grep ^${virtual_host_key_prefix} | head -1
  )

  if [ -n $first_virtual_host ]; then
    first_publication=$(
      echo  $first_virtual_host | \
        sed "s#${virtual_host_key_prefix}##" | \
        cut -d'=' -f1
    )
    first_website=$(
      echo  $first_virtual_host | \
        cut -d'=' -f2 | \
        cut -d':' -f1
    )
    trail_publication_name=$first_publication
    trail_webapp_name=$first_publication
    trail_website_name=$first_website
  fi

  if [ -n "${trail_publication_domain_mapping_list}" ]; then
    # create a list of all virtual hosts
    
    for el in $trail_publication_domain_mapping_list; do
      IFS='#' read ece_pub fqdn alias <<< "$el"
      trail_virtual_host_list="${trail_virtual_host_list} ${fqdn}"
    done
  
  fi
  
  expand_all_variables_in_org_files
}

function set_defaults_if_the_trails_are_not_set() {
  trail_analysis_host=${trail_analysis_host-analysis1}
  trail_builder_host=${trail_builder_host-builder1}
  trail_builder_user=${trail_builder_user-buildy}
  trail_control_host=${trail_control_host-control}
  trail_db_master_host=${trail_db_master_host-db1}
  trail_db_schema=${trail_db_schema-ecedb}
  trail_db_backup_dir=${trail_db_backup_dir-/var/backups/escenic}
  trail_db_vendor=${trail_db_vendor-mysql}
  trail_db_vip_interface=${trail_db_vip_interface-eth0:0}
  trail_db_vip_ip=${trail_db_vip_ip-192.168.1.200}
  trail_editor_host=${trail_editor_host-edit1}
  trail_editor_port=${trail_editor_port-8080}
  trail_import_host=${trail_import_host-edit2}
  trail_import_port=${trail_import_port-8080}
  trail_search_host=${trail_search_host-localhost}
  trail_search_port=${trail_search_port-8081}
  trail_monitoring_host=${trail_monitoring_host-mon}
  trail_network_name=${trail_network_name}
  trail_dot_network_name=$(get_network_name)
  trail_nfs_client_mount_point_parent=${trail_nfs_client_mount_point_parent-/mnt}
  trail_nfs_export_list=${trail_nfs_export_list-/var/exports/multimedia}
  trail_nfs_master_host=${trail_nfs_master_host-nfs1}
  trail_presentation_host=${trail_presentation_host-pres1}
  trail_presentation_host_list=${trail_presentation_host_list-${trail_presentation_host}}
  trail_today_date=${trail_today_date-$(date --iso)}
  trail_today_date_full=${trail_today_full-$(date)}
}

function expand_all_variables_in_org_files() {
  set_defaults_if_the_trails_are_not_set

  declare | grep ^trail_ | while read el; do
    local old_ifs=$IFS
    IFS='='
    read key value <<< "$el"
    IFS=$old_ifs
    
    # must read this from the sourced variable and not the declare
    # registry to get unicode encoded characters right.
    value=$(eval echo $`echo $key`)

    value=$(echo $value | sed -e "s~^'~~" -e "s~'$~~")
    find $target_dir -name "*.org" | while read f; do
      sed -i -e "s~<%=[ ]*${key}[ ]*%>~${value}~g" -e "s~^'~~" ${f}
    done
  done
}

function set_up_build_directory() {
  if [[ -n "$target_dir" && -d $target_dir ]]; then
    rm -rf $target_dir
  fi
  run mkdir -p $target_dir/graphics
  run cp $(dirname $0)/*.{org,el} $target_dir

  # customer chapters & overrides
  if [[ -n $customer_doc_dir && -d $customer_doc_dir ]]; then
    run mkdir -p $target_dir/customer
    
    if [ $(ls $customer_doc_dir/*.org 2>/dev/null | wc -l) -gt 0 ]; then
      echo "Copying chapter overides from $customer_doc_dir ..."
      run cp $customer_doc_dir/*.org $target_dir/customer/
    fi
    local dir=$customer_doc_dir/extra-chapters
    if [ -d $dir ]; then
      echo "Copying extra customer chapters from $dir"
      run cp -r $dir $target_dir/customer/extra-chapters/
    fi
  fi
}

function get_blockdiag_defs() {
  if [ -n "$trail_db_master_host" ]; then
    echo " " $trail_db_master_host '[shape = "flowchart.database" ];'
  fi
  if [ -n "$trail_db_slave_host" ]; then
    echo " " $trail_db_slave_host '[shape = "flowchart.database" ];'
  fi
  if [ -n "$trail_presentation_host_list" ]; then
    for el in $trail_presentation_host_list; do
      echo " " $el '[color = "orange" ];'
    done
  fi
  if [ -n "$trail_editor_host" ]; then
    echo " " $trail_editor_host '[color = "orange" ];'
  fi
  if [ -n "$trail_import_host" ]; then
    echo " " $trail_import_host '[color = "orange" ];'
  fi
  if [ -n "$trail_analysis_host" ]; then
    echo " " $trail_analysis_host '[color = "yellow" ];'
  fi
  if [ -n "$trail_db_vip_host" ]; then
    echo " " $trail_db_vip_host '[shape = roundedbox];'
  fi
  if [ -n "$trail_nfs_vip_host" ]; then
    echo " " $trail_nfs_vip_host '[shape = roundedbox];'
  fi
  if [ -n "$trail_lb_host" ]; then
    echo " " $trail_lb_host '[shape = roundedbox];'
  fi
}

function get_blockdiag_groups() {
  # serving presentation
  echo "  group {"
  echo "    internet;"
  if [ -n "$trail_lb_host" ]; then
    echo "    $trail_lb_host;"
  fi
  if [ -n "$trail_presentation_host_list" ]; then
    for el in $trail_presentation_host_list; do
      echo "    $el;"
    done
  fi
  if [ -n "$trail_analysis_host" ]; then
    echo "    $trail_analysis_host;"
  fi
  echo '    color = "white";'
  echo "  }"
}

function get_blockdiag_call_flow() {
  # from the internet and to the ECEs
  local lb_call_flow="internet ->"
  if [ -n "$trail_lb_host" ]; then
    lb_call_flow="$lb_call_flow $trail_lb_host ->"
  fi
  for el in $trail_presentation_host_list; do
    lb_call_flow="$lb_call_flow ${el},"
  done
  echo " " "$(echo ${lb_call_flow} | sed 's/,$//g');"
  
  if [ -n "$trail_editor_host" ]; then
    echo "  journalist -> $trail_editor_host" \
      '[ label = "writes" ];'
  fi
  if [ -n "$trail_import_host" ]; then
    echo "  xml-feeds -> $trail_import_host" \
      '[ label = "imports" ];'
  fi
  
  # ECEs
  for el in \
    $trail_presentation_host_list \
    $trail_editor_host \
    $trail_import_host; do
    local one_flow="$el ->"

    if [ -n "$trail_db_vip_host" ]; then
      one_flow="${one_flow} $trail_db_vip_host,"
    elif [ -n "$trail_db_master_host" ]; then
      one_flow="${one_flow} $trail_db_master_host,"
    fi
    if [ -n "$trail_nfs_vip_host" ]; then
      one_flow="${one_flow} $trail_nfs_vip_host,"
    elif [ -n "$trail_nfs_master_host" ]; then
      one_flow="${one_flow} $trail_nfs_master_host,"
    fi
    echo " " ${one_flow} | sed 's/,$/;/g'
  done

  for el in $trail_presentation_host_list; do
    if [ -n "$trail_analysis_host" ]; then
      echo "  $el -> $trail_analysis_host;"
    fi
  done
  
  # DB
  if [ -n "$trail_db_vip_host" -a \
    -n "$trail_db_master_host" -a \
    -n "$trail_db_slave_host" ]; then
    echo " " $trail_db_vip_host "->" \
      $trail_db_master_host"," \
      $trail_db_slave_host";"
  fi
  if [ -n "$trail_db_master_host" -a \
    -n "$trail_db_slave_host" ]; then
    echo " " $trail_db_master_host "<->" $trail_db_slave_host \
      '[ label = "syncs" ];'
  fi

  # NFS
  if [ -n "$trail_nfs_vip_host" -a \
    -n "$trail_nfs_master_host" -a \
    -n "$trail_nfs_slave_host" ]; then
    echo " " $trail_nfs_vip_host "->" \
      $trail_nfs_master_host"," \
      $trail_nfs_slave_host";"
  fi
  if [ -n "$trail_nfs_master_host" -a \
    -n "$trail_nfs_slave_host" ]; then
    echo " " $trail_nfs_master_host "<->" $trail_nfs_slave_host \
      '[ label = "syncs" ];'
  fi
}

function generate_architecture_diagram() {
  local file=$target_dir/graphics/architecture.blockdiag
  cat > $file <<EOF
# generated by $(basename $0) @ $(date)
blockdiag {
  orientation = "portrait";
  journalist [ shape = "actor" ];
  internet [ shape = "cloud" ];

$(get_blockdiag_defs)

$(get_blockdiag_call_flow)
}
EOF
}

function generate_html_from_org() {
# use emacs to generate HTML from the ORG files
  echo "Generating new handbook HTML from ORG ..." 
  run emacs \
    --load $target_dir/vizrt-branding-org-mode.el \
    --batch \
    --visit $target_dir/$handbook_org \
    --funcall org-export-as-html-batch 2> /dev/null
  echo "$target_dir/$(basename $handbook_org .org).html is now ready"
}

function get_network_name() {
  if [ -n "$trail_network_name" ]; then
    echo ".${trail_network_name}"
  else
    echo ""
  fi
}

## $1 :; the host (not FQDN)
function get_fqdn() {
  for el in $host_name_list_outside_network; do
    if [ $(echo $1 | grep $el | wc -l) -gt 0 ]; then
      echo "network outside: $el" "$1"
      return
    fi
  done
  
  echo "${1}$(get_network_name)"
}

## $1 :; the host (not FQDN)
function get_link() {
  echo "http://$(get_fqdn $1)"
}

function get_generated_overview() {
  cat <<EOF
** Machines & Their Services
EOF
  get_machine_matrix_header

  if [ -n "$trail_staging_editor_host" ]; then
    echo $(get_editor_host_overview \
      $trail_staging_editor_host \
      $trail_staging_editor_port
    )
  fi

  if [ -n "${trail_monitoring_host}" ]; then
    cat <<EOF 
| $(get_fqdn $trail_monitoring_host) | \
  [[$(get_link ${trail_monitoring_host}):${trail_monitoring_port-80}/munin/][munin]] \
  [[$(get_link ${trail_monitoring_host}):${trail_monitoring_port-80}/icinga/][icinga]] \
  [[$(get_link ${trail_monitoring_host}):5679][hugin]] \
|
#EOF
#  fi
#  
#  if [ -n "${trail_control_host}" ]; then
#    cat <<EOF 
#| $(get_fqdn $trail_control_host) | \
#  [[$(get_link $trail_control_host):5679][hugin]] \
#|
EOF
  fi

  if [ -n "${trail_editor_host}" ]; then
    echo $(
      get_editor_host_overview \
        $trail_editor_host \
        $trail_editor_port
    )
  fi
  
  if [ -n "${trail_import_host}" ]; then
    echo $(
      get_editor_host_overview \
        $trail_import_host \
        $trail_import_port
    )
  fi
  
  for el in nop $trail_presentation_host_list; do
    if [[ $el == "nop" ]]; then
      continue
    fi
    echo $(
      get_presentation_host_overview \
        $el \
        8080
    )
  done
  
  if [ -n "${trail_analysis_host}" ]; then
    cat <<EOF 
| $(get_fqdn ${trail_analysis_host}) | \
  [[$(get_link ${trail_analysis_host}):5678/][system-info]] \
  [[$(get_link ${trail_analysis_host}):${trail_analysis_port-8080}/analysis-reports/][analysis-reports]] \
  [[$(get_link ${trail_analysis_host}):${trail_analysis_port-8080}/analysis-logger/admin][analysis-logger]] \
  [[$(get_link ${trail_analysis_host}):${trail_analysis_port-8080}/analysis-qs/admin][analysis-qs]] \
|
EOF
  fi
  
  for el in nop $trail_nfs_master_host \
    $trail_nfs_slave_host \
    $trail_db_master_host \
    $trail_db_slave_host; do
    if [[ $el == "nop" ]]; then
      continue
    fi
    echo $(
      get_simple_host_overview $el
    )
  done
}

function get_machine_matrix_header() {
  cat <<EOF
|-------------------------------------------|
| Machine     | Service quick links         |
|-------------------------------------------|
EOF
}

function get_machine_matrix_footer() {
  cat <<EOF
|-------------------------------------------|
EOF
}

## $1 :: host
## $2 :: port
function get_editor_host_overview() {
  local ece_url="$(get_link ${1})"
  cat <<EOF
| $(get_fqdn ${1}) | \
  [[$(get_link ${1}):5678/][system-info]] \
  [[${ece_url}:${2-8080}/escenic-admin/][escenic-admin]] \
  [[${ece_url}:${2-8080}/escenic-admin/top][top]] \
  [[${ece_url}:${trail_search_port-8081}/solr/admin/][solr]] \
  [[${ece_url}:${2-8080}/studio/][studio]] \
  [[${ece_url}:${2-8080}/escenic/][escenic]] \
  [[${ece_url}:${2-8080}/webservice/][webservice]] \
  [[${ece_url}:${2-8080}/escenic-admin/browser/Webapp%20ECE%20Webservice%20Webapp/com/escenic/servlet/filter/cache/AuthenticationFilterCache][logged in users]]
|
EOF
}

## $1 :: host
function get_presentation_host_overview() {
  cat <<EOF 
| $(get_fqdn ${1}) | \
  [[$(get_link ${1}):5678/][system-info]] \
  [[$(get_link ${1}):${2-8080}/escenic-admin/][escenic-admin]] \
  [[$(get_link ${1}):${2-8080}/escenic-admin/top][top]] \
  [[$(get_link ${1}):${trail_search_port-8081}/solr/admin/][solr]] \
  $(get_publication_links_for_presentation_host $1) \
|
EOF
  
}

function get_publication_links_for_presentation_host() {
  if [ -z "$trail_publication_domain_mapping_list" ] ; then
    return ""
  fi
  
  for el in $trail_publication_domain_mapping_list; do
    local old_ifs=$IFS
    IFS='#'
    read ece_pub fqdn domain_prefix <<< "$el"
    IFS=$old_ifs
    echo "[[$(get_link ${domain_prefix}.${1})/][${fqdn}]]"
  done
}

## $1 :: host
function get_simple_host_overview() {
  cat <<EOF 
| $(get_fqdn ${1}) | \
  [[$(get_link ${1}):5678/][system-info]] \
|
EOF
}

## included from overview.org
function generate_overview_org() {
  local file=$target_dir/overview-generated.org
  cat > $file <<EOF
$(get_generated_overview)
EOF
}

function generate_cache_server_diagram() {
  if [ -z "$trail_cache_host" ]; then
    return
  fi
  
  local file=$target_dir/graphics/${trail_cache_host}-cache.blockdiag
  cat > $file <<EOF
# Cache server on $trail_cache_host generated by $(basename $0) @ $(date)
blockdiag {
EOF

  if [ -n "$trail_cache_backend_servers" ]; then
    for el in $trail_cache_backend_servers; do
      local appserver_host=$(echo $el | cut -d':' -f1)
      local appserver_port=$(echo $el | cut -d':' -f2)
      cat >> $file <<EOF
  "${appserver_host}:${appserver_port}" [ color = "orange" ];
  "varnish:${trail_cache_port-80}" -> "${appserver_host}:${appserver_port}";
EOF
    done
  else
    cat >> $file <<EOF
  "tomcat:8080" [ color = "orange" ];
  "varnish:${trail_cache_port-80}" -> "tomcat:8080";
EOF
  fi
  echo "}" >> $file

}

## included from cache-server.org
function generate_cache_server_org() {
  # if the trail_cache_host is not set, we assume the cache is running
  # on (at least one o) the presentation servers.
  if [ -z "$trail_cache_host" ]; then
    trail_cache_host=$trail_presentation_host
  fi

  generate_cache_server_diagram
  local file=$target_dir/generated-cache-server.org
  local svg_file=./graphics/${trail_cache_host}-cache.svg
  cat > $file <<EOF
** Cache server on $trail_cache_host

The cache server on $trail_cache_host is available on
$(get_link ${trail_cache_host}):${trail_cache_port-80}

#+ATTR_HTML: alt="Cache server on $trail_cache_host"
[[file:${svg_file}][${svg_file}]]
EOF
}

function generate_db_diagram() {
  local file=$target_dir/graphics/db.blockdiag
  cat > $file <<EOF
# generated by $(basename $0) @ $(date)
blockdiag {
  "content-engine" [ color = "orange" ];
  "content-engine" -> "${trail_db_vip_host-${trail_db_master_host-${trail_db_host-mydb}}}";
EOF
  if [ -n "$trail_db_master_host" ]; then
    cat >> $file <<EOF
  "${trail_db_master_host}" [shape = "flowchart.database" ];
EOF
  fi
  if [ -n "$trail_db_slave_host" ]; then
    cat >> $file <<EOF
  "${trail_db_slave_host}" [shape = "flowchart.database" ];
  "${trail_db_master_host}" <-> "${trail_db_slave_host}" [ label = "syncs" ];
EOF
  fi
  
  if [ -n "$trail_db_vip_host" ]; then
    cat >> $file <<EOF
  "${trail_db_vip_host}";
  "$trail_db_vip_host" -> "${trail_db_master_host-${trail_db_host}}";
EOF
  fi

  echo "}" >> $file
}

function generate_db_org() {
  generate_db_diagram

  if [[ -n "${trail_db_master_host}" && -n "${trail_db_slave_host}" ]]; then
    run cat $target_dir/database-changing-master.org >> $target_dir/database.org
  fi
  if [[ -n "${trail_db_vip_host}" && \
        -n "${trail_db_master_host}" && \
        -n "${trail_db_slave_host}" ]]; then
    run cat $target_dir/database-changing-vip.org >> $target_dir/database.org
  fi
  if [ $(echo "${trail_db_vendor}" | \
    tr [A-Z] [a-z] | \
    grep ${DB_VENDOR_AMAZON_RDS} | \
    wc -l) -gt 0 ]; then
    run cat $target_dir/database-rds.org >> $target_dir/database.org
  fi
}

function generate_nfs_org() {
  if [[ -n "${trail_nfs_master_host}" && -n "${trail_nfs_slave_host}" ]]; then
    local blockdiag_file=$target_dir/graphics/network-file-system-sync.blockdiag
    cat > $blockdiag_file <<EOF
blockdiag {
  "${trail_nfs_master_host}";
  "${trail_nfs_slave_host}";
  "${trail_nfs_slave_host}" -> "${trail_nfs_master_host}" [label = "reads"];
}
EOF
    local file=$target_dir/network-file-system-sync.org
    local svg_file=./graphics/$(basename $blockdiag_file .blockdiag).svg
    cat >> $file <<EOF
[[file:${svg_file}][${svg_file}]]
EOF
    run cat $file >> $target_dir/network-file-system.org
  fi
}

function generate_content_engine_diagram() {
  local file=$target_dir/graphics/content-engine.blockdiag
  local the_db="${trail_db_vendor-mysql}:${trail_db_master_port-${trail_db_port-3306}}"
  
  cat > $file <<EOF
blockdiag {

  "content-engine" [ color = "orange" ];
  "${the_db}" [shape = "flowchart.database" ];
  "content-engine" -> "memcached:11211";
  "content-engine" -> "${the_db}";
  "content-engine" -> "${trail_nfs_vip_host-${trail_nfs_master_host-${trail_nfs_host}}}:2049";
EOF

  if [ -n "${trail_analysis_host}" ]; then
    cat >> $file <<EOF
  "content-engine" -> "${trail_analysis_host}:${trail_analysis_port-8080}";
EOF
  fi

  if [ -n "$trail_search_host" ]; then
    cat >> $file <<EOF
  "content-engine" -> "${trail_search_host}:${trail_search_port}/solr";
EOF
  fi
  
  
  
  cat >> $file <<EOF
}
EOF
}

function generate_content_engine_org() {
  generate_content_engine_diagram
}

function generate_backup_org() {
  if [ -n "${trail_db_daily_backup_host}" ]; then
    run cat $target_dir/backups-db.org >> $target_dir/backups.org
  fi
}

function add_customer_chapters() {
  if [ $(ls $target_dir/customer 2>/dev/null | \
    grep .org$ | \
    wc -l) -gt 0 ]; then
    echo "Applying customer overrides ..."
    cp $target_dir/customer/*.org $target_dir
  fi

  if [ $(ls $target_dir/customer/extra-chapters/ 2>/dev/null | \
    grep .org$ | \
    wc -l) -gt 0 ]; then
    (
      local file=$target_dir/vosa-handbook.org
      local title="Customer specific chapters"
      if [ -n "$trail_network_name" ]; then
        title="Special chapters for the $trail_network_name network"
      fi
      cat >> $file <<EOF
* ${title}
EOF
      for el in $target_dir/customer/extra-chapters/*.org; do
        echo "Preparing extra chapter $(basename $el .org) ..."
        sed -i 's/^*/**/' $el
      done

      if [ -e $target_dir/customer/extra-chapters/overview.org ]; then
        echo "Including extra chapters according to customer's overview.org"
        cat >> $file <<EOF
#+INCLUDE "customer/extra-chapters/overview.org"
EOF
      else
        for el in $target_dir/customer/extra-chapters/*.org; do
          echo "Appending chapter $el ..."
          cat $el >> $file
        done
      fi
    )
  fi
}

function generate_virtualization_overview_org() {
  if [ -z "$trail_virtualization_map" ]; then
    return
  fi

  local file=$target_dir/virtualization-overview-generated.org
  cat > $file <<EOF
** Virtualization Overview
Here's an overview of your virtualization hosts & their guests:

|-------------------------------------------|
| Virtualization host | IP | Virtualization guests |
|-------------------------------------------|
EOF
  for el in $trail_virtualization_map; do
    local old_ifs=$IFS
    IFS='#'
    read host ip guests <<< "$el"
    IFS=$old_ifs
    echo -n "| $(get_fqdn $host) | $ip | " >> $file
    for ele in $(echo "$guests" | sed 's/,/ /g'); do
      echo -n " [[$(get_link $ele):5678][$(get_fqdn $ele)]] " >> $file
    done
    echo "|" >> $file
  done

  cat >> $file <<EOF
|-------------------------------------------|

For more background and documentation on virtualization hosts &
guests, see the
[[http://docs.redhat.com/docs/en-US/Red_Hat_Enterprise_Linux/6/html-single/Virtualization_Host_Configuration_and_Guest_Installation_Guide][Virtualization Host Configuration and Guest Installation Guide]]
from RedHat.
EOF

  cat $file >> $target_dir/overview-generated.org
}
function generate_aws_overview_org() {
  if [ -z "$trail_aws_map" ]; then
    return
  fi

  local file=$target_dir/aws-overview-generated.org
  cat > $file <<EOF
** Amazon Overview
Here's an overview of your AWS Region, availability zones and  instances:

|----------------------------|
| Zone | Subnet  | Instances  |
|----------------------------|
EOF
  for el in $trail_aws_map; do
    local old_ifs=$IFS
    IFS='#'
    read az subnet instances <<< "$el"
    IFS=$old_ifs
    echo -n "| $az | $subnet | " >> $file
    for ele in $(echo "$instances" | sed 's/,/ /g'); do
      echo -n " [[$(get_link $ele):5678][$(get_fqdn $ele)]] " >> $file
    done
    echo "|" >> $file
  done

  cat >> $file <<EOF
|-----------------------------|

[[https://${trail_aws_account_alias}.signin.aws.amazon.com/console][AWS Management Console $trail_customer_shortname]]

EOF

  cat $file >> $target_dir/overview-generated.org
}

function get_user_input() {
  local customer_doc_dir_is_next=0
  local customer_conf_is_next=0
  conf_file=$(basename $0 .sh).conf

  for el in $@; do
    if [[ "$el" == "--doc-dir" || "$el" == "-i" ]]; then
      customer_doc_dir_is_next=1
    elif [[ "$el" == "--conf-file" || "$el" == "-f" ]]; then
      customer_conf_is_next=1
    elif [ $customer_conf_is_next -eq 1 ]; then
      conf_file=$el
      customer_conf_is_next=0
    elif [ $customer_doc_dir_is_next -eq 1 ]; then
      customer_doc_dir=$el
      customer_doc_dir_is_next=0
    fi
  done
}

echo "Building the $trail_customer_shortname VOSA Guide"
get_user_input $@
set_up_build_directory
set_customer_specific_variables
add_customer_chapters
generate_architecture_diagram
generate_overview_org
generate_content_engine_org
generate_cache_server_org
generate_db_org
generate_nfs_org
generate_backup_org
generate_virtualization_overview_org
generate_aws_overview_org
generate_html_from_org
generate_svg_from_blockdiag
echo "done: http://start.vizrtsaas.com/${trail_customer_acronym}/" 

