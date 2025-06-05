

/Users/sgoldberg/Documents/projects/ALL_CONFIGS/wlp/bin/server run dev_remote \
    -Xms512m \
    -Xmx3072m \
    -Dlog4j2.configurationFile=file:/Users/sgoldberg/Documents/Projects/ALL_CONFIGS/configs/log4j2.xml\
    -Dhazelcast.logging.type=log4j2\
    -Dewms.system.properties.path=file:/Users/sgoldberg/Documents/Projects/ALL_CONFIGS/configs/ewms-system.properties\
    -Dtms.program.propeties.path=file:/Users/sgoldberg/Documents/Projects/ALL_CONFIGS/configs/tms-program-properties.properties\
    -Dspring.profiles.active=DEV\
    -Dquartz.properties=file:/Users/sgoldberg/Documents/Projects/ALL_CONFIGS/configs/quartz.properties\
    -Dlog4jWatcher.be.configuration=file:/Users/sgoldberg/Documents/Projects/ALL_CONFIGS/configs/log4j.properties
echo "!!!!!  USCS-BE Has Stopped !!!!!"%