function update_publication_resources() {
  if [[ ! -r $resource && -z "$1" ]]; then
    print $resource "doesn't exist. I will exit :-("
    exit 1
  fi

  if [ -z $publication ]; then
    print "You must specify which publication to update (-p <publication>)"
    exit 1
  fi

  local found=0
  local publication_list=$(get_publication_list ${appserver_port-8080})
  for el in $publication_list; do
    if [[ "$publication" == "$el" ]]; then
      found=1
    fi
  done

  if [ $found -eq 0 ]; then
    print "There is no publication called" \
      $publication "(only $publication_list)"
    exit 1
  fi

  local url=$(get_escenic_admin_url)/publication-resources

  case "$(basename $resource)" in
    content-type)
      url=${url}/${publication}/escenic/content-type
      ;;
    feature)
      url=${url}/${publication}/escenic/feature
      ;;
    layout)
      url=${url}/${publication}/escenic/layout
      ;;
    layout-group)
      url=${url}/${publication}/escenic/layout-group
      ;;
    image-version)
      url=${url}/${publication}/escenic/image-version
      ;;
    teaser-type)
      url=${url}/${publication}/escenic/teaser-type
      ;;
    menu)
      url=${url}/${publication}/escenic/plugin/menu
      ;;
    section-feed)
      url=${url}/${publication}/escenic/plugin/section-feed
      ;;
    security)
      url=${url}/${publication}/escenic/plugin/community/security
      ;;
    root-section-parameters)
      do_put=true
      url=$(get_escenic_admin_url)
      url=${url}/publication-resources/${publication}/0/escenic/section-parameter
      ;;
    *)
      print "Invalid resource: $(basename $resource) :-("
      exit 1
  esac

  local tmp_dir=$(mktemp -d)

  if [ $1 ]; then
    if [[ -z "$EDITOR" || ! -x $(which $EDITOR) ]]; then
      print "You must have a valid editor defined in your EDITOR variable"
      exit 1
    fi

    run cd $tmp_dir;

    if [[ "${command}" == edit ]]; then
      # adding auth credentials for the appserver (if set)
      run wget $wget_appserver_auth $url -O ${resource}
    elif [[ "${command}" == create ]]; then
      touch "${resource}"
    fi

    md5sum ${resource} > ${resource}.md5sum
    exit_on_error "md5sum ${resource}"

    $EDITOR ${resource}
    md5sum -c ${resource}.md5sum \
      1>>$log \
      2>>$log
    if [ $? -eq 0 ]; then
      print "You didn't make any changes to ${resource}, I will exit."
      exit 1
    fi
  fi

  print "Updating the $(basename $resource) resource for the $publication" \
    "publication ..."

  log POSTing $resource to $url
  if [[ -n "$do_put" && "$do_put" == "true" ]]; then
    run curl -T ${resource} \
      ${curl_appserver_auth} \
      --fail \
      ${url}
  else
    run wget $wget_appserver_auth \
      --output-document - \
      --server-response \
      --post-file ${resource} \
      $url
  fi

  if [ -d $tmp_dir ]; then
    run rm -rf $tmp_dir
  fi
}
