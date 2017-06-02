# this script is repsonsible for configuring the special plugins like seo, mobile-studio

function configure_seo(){
    if [ $install_profile_number -ne $PROFILE_ANALYSIS_SERVER -a \
        $install_profile_number -ne $PROFILE_SEARCH_SERVER ]; then
        print_and_log "Configuring seo plugin ..."
        local solr_presentation_url=http://${search_host}:${solr_port}/solr/presentation
        if [ ${fai_search_legacy-0} -eq 1 ]; then
            solr_presentation_url=http://${search_host}:${search_port}/solr/presentation
        fi
            xmlstarlet ed -P -L \
                -s /Context -t elem -n TMP -v '' \
                -i //TMP -t attr -n name -v escenic/presentation-solr-base-uri \
                -i //TMP -t attr -n value -v ${solr_presentation_url}  \
                -i //TMP -t attr -n type -v java.lang.String \
                -i //TMP -t attr -n override -v false \
                -r //TMP -v Environment \
                $tomcat_base/conf/context.xml
        fi
}

function configure_mobile_studio(){
    print_and_log "Configuring mobile-studio ..."
    if [ -d $tomcat_base/webapps/webservice ]; then
        cd $tomcat_base/webapps/
        ln -s webservice $tomcat_base/webapps/mobile-webservice
    fi
}

function configure_special_plugins(){
    print_and_log "Checking for special plugins ..."
    if [[ $type == "engine" && -e $escenic_conf_dir/ece-$instance_name.conf ]]; then
        source $escenic_conf_dir/ece-$instance_name.conf
        if [[ "$ear_download_list" =~ "seo-" ]]; then
            configure_seo
        fi
        if [[ "$ear_download_list" =~ "mobile-studio-" ]]; then
            configure_mobile_studio
        fi
    fi
}
