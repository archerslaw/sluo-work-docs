#!/bin/bash

#if HOSTNAME="",job will search available machine to reserve.
#if KICKSTART="",will install os with the latest ks.
#Default RESERVETIME is 24h,maximum of 356400 seconds (99 hours),you can define the duration (in seconds)
#HOST_CONTROL defines in which lab to select machine.  

HOSTNAME=""
KICKSTART=""
RESERVETIME="86400" 
KS_URL="http://pxe.englab.nay.redhat.com/kickstarts/kvm/RHEL7/"
HOSTTYPE="RHEV-7.2-Server"
NETWORK="bridge"   
REG="^ak.*$HOSTTYPE.*$NETWORK"
JOB="job_reserve.xml"


get_ks(){

    if [[ "$KICKSTART" != "" ]]; then
        rm -rf $KICKSTART*
        wget $KS_URL$KICKSTART
        if [[ $? -eq 0 ]]; then
            return 0
        fi
    fi
    reg=$1
    ks_url=$2
    hosttype=$3
    rm -rf index.html*
    wget -c $KS_URL
    LATEST_KS=`awk -F"\"" '{print $8}' index.html | grep $reg | tail -n1`
    if [[ $LATEST_KS == "" ]]; then
        return 1
    fi
    PREV_KS=`ls |grep $reg`
    if [[ "$LATEST_KS" == $PREV_KS ]]; then
        return 1
    fi
    rm -rf $PREV_KS
    wget $KS_URL$LATEST_KS
    
    if [[ $? -eq 0 ]]; then
        KICKSTART=$LATEST_KS
	return 0
    fi
    return 1
}

# Create beaker job xml
create_beaker_xml () {
    
    rm -rf $JOB
    # Get the distro info from kickstart
    SIG=`grep "url --url" $KICKSTART | awk -F "/" '{print $8}'`
    if [[ "$SIG" == "compose" ]]; then
        DISTRO_NAME=`grep "url --url" $KICKSTART | awk -F"/" '{print $7}'`
    else
        DISTRO_NAME=`grep "url --url" $KICKSTART | awk -F"/" '{print "RHEL-"$8}'`
    fi
    DISTRO_FAMILY="RedHatEnterpriseLinux"`echo $DISTRO_NAME | cut -b 6`
    
    #Create job.xml
    echo "<job retention_tag=\"scratch\">
    <whiteboard>
        Reserve and install with $KICKSTART
    </whiteboard>
    <recipeSet priority=\"High\">
        <recipe kernel_options=\"\" kernel_options_post=\"\" ks_meta=\"\" role=\"RECIPE_MEMBERS\" whiteboard=\"\">
            <autopick random=\"false\"/>
            <watchdog panic=\"ignore\"/>
            <packages/>
            <ks_appends>
                <ks_append>
<![CDATA[
" > $JOB

    # Modify the kickstart and put it into job.xml    
    grep rootpw $KICKSTART >> $JOB
    sed '0, /^reboot$/d' $KICKSTART | grep "rm -rf /etc/yum.repos.d/*" -v | grep "sed -i '/upgrade-pkg.sh/ s/^./#./' /etc/rc.d/rc.local" -v | grep "^reboot" -v >> $JOB
    sed -i '/upgrade-pkg.log/ s/^./#./' $JOB
 
    echo "]]>  
                </ks_append>
            </ks_appends>
            <repos/>
            <distroRequires>
                <and>
                    <distro_family op=\"=\" value=\"$DISTRO_FAMILY\"/>
                    <distro_variant op=\"=\" value=\"Server\"/>
                    <distro_name op=\"=\" value=\"$DISTRO_NAME\"/>
                    <distro_arch op=\"=\" value=\"x86_64\"/>
                </and>
            </distroRequires>
            <hostRequires>
                <and>
                    <hostname op=\"like\" value=\"$HOSTNAME\"/>
		    <arch op=\"=\" value=\"x86_64\"/>
		    <key_value key=\"CPUFLAGS\" op=\"=\" value=\"svm\"/>
                    <system_type op=\"=\" value=\"Machine\"/>
		    <hostlabcontroller op=\"=\" value=\"lab-02.rhts.eng.nay.redhat.com\"/>
                </and>
	    </hostRequires>
            <partitions/>
            <task name=\"/distribution/install\" role=\"STANDALONE\"/>
            <task name=\"/virt/kvmauto-task/Sanity/upgrade-package\" role=\"STANDALONE\"/>
            <task name=\"/distribution/utils/reboot\" role=\"STANDALONE\"/>
	    <task name=\"/distribution/reservesys\" role=\"STANDALONE\">
  		<params>
    			<param name=\"RESERVETIME\" value=\"$RESERVETIME\" />
 		</params>
	    </task>
        </recipe>
    </recipeSet>
</job>
" >> $JOB

}

echo "######get latest ks######"
get_ks $REG $KS_URL $HOSTTYPE


if [[ $? == 0 ]]; then
    echo "######create job xml######"
    create_beaker_xml
    echo "######JOB=$JOB######"
    exit 0
fi

exit 1



