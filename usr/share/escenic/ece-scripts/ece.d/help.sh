function print_help() {
  cat <<EOF
Usage: $(basename $0) [-t <type>] [-i <instance>] <command>
"
DESCRIPTION"
-t --type <type>
     The following types are available:
       engine  -  The Escenic Content Engine, this is the default
                  and is the assumed type if none is specified.
       search  -  A standalone search indexer and solr instance
       rmi-hub -  The RMI hub responsible for the internal 
                  communication between the ECE instances.
       analysis - The Escenic Analysis Engine also knows as 'Stats'

 -i --instance <instance> 
      The type instance, such as editor1, engine1 or search1

 -f --file <file> } --uri <uri>
      Specificies the file that the given comand shall act upon.
      Right now, this only entails the 'deploy' command.

 -p --publication <publication> 
      Needed only for updating publication resources

 -r --resource <resource> 
      Used for updating publication resources.
      Must be one of: content-type, feature, layout, layout-group
                      image-version, menu
 -q --quiet
      Makes $(basename $0) as quiet as possible.

 -v --verbose
      Prints out debug statements, useful for debugging.

The following commands are available:
   applog         the type's app server log
   assemble       runs the Assembly Tool *)
   backup         backs up an entire instance (takes time)
   clean          removes temporary files created by $(basename $0) *)
   deploy         deploys the assembled EAR *)
   edit           lets you edit a publication resource
   flush          flushes all ECE caches ('Clear all caches') *)
   help           prints this help screen
   info           prints various info about the selected ECE instance
   kill           uses force to stop the type
   list-instances list all instances on $HOSTNAME
   list-logs      list all the log paths
   log            the type's log4j log **)
   outlog         the $id script log (system out log)
   restart        restarts the type
   run            runs type in the foregrand. Useful for containers.
   start          starts the type
   status         checks if the type is running
   stop           stops the type
   threaddump     write a thread dump to standard out (system out log)
   update         update publication resources
   versions       lists the ECE component versions

*) only applicable if type is 'engine'
**) not applicable if type is 'rmi-hub'
EOF
}    
