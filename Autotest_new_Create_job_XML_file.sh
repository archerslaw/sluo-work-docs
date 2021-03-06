#!/bin/bash

#if HOSTNAME="",job will search available machine to reserve.
#if KICKSTART="",will install os with the latest ks.
#Default RESERVETIME is 24h,maximum of 356400 seconds (99 hours),you can define the duration (in seconds)
#HOST_CONTROL defines in which lab to select machine. 
 
HOSTNAME=""
CPUFLAG="vmx" 
KICKSTART="ak-RHEL-7.2-Server-x86_64-3.10.0-243-qemu-kvm-1.5.3-87.el7-2015-04-30-bridge.cfg"
PYTHON_CMD="python ConfigTest.py --testcase=boot --guestname=RHEL.7.1 --drive_cache=unsafe"
KS_URL="http://pxe.englab.nay.redhat.com/kickstarts/kvm/RHEL7/"
JOB_NAME="gaoxia's job run accptance"

NFS_LOG="10.66.90.121:/vol/s2coredump/test_result"
JOB="job_rhev7.xml"
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
        $JOB_NAME
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
                    <system_type op=\"=\" value=\"Machine\"/>
                    <key_value key=\"CPUFLAGS\" op=\"=\" value=\"$CPUFLAG\"/>
		    <hostlabcontroller op=\"=\" value=\"lab-02.rhts.eng.nay.redhat.com\"/>
                </and>
            </hostRequires>
            <partitions/>
            <task name=\"/distribution/install\" role=\"STANDALONE\"/>
	    <task name=\"/virt/kvmauto-task/Sanity/upgrade-package\" role=\"STANDALONE\"/>
            <task name=\"/distribution/utils/reboot\" role=\"STANDALONE\"/>
	    <task name=\"/virt/kvmauto-task/Sanity/run-kvm-autotest-common\" role=\"STANDALONE\">
		<params>
			<param name=\"PYTHON_CMD\" value=\"$PYTHON_CMD\"/>
                        <param name=\"NFS_LOG\" value=\"$NFS_LOG\"/>
		</params>
	    </task>
	</recipe>
    </recipeSet>
</job>
" >> $JOB

}

wget $KS_URL$KICKSTART
echo "######create job xml######"
create_beaker_xml
echo "######JOB:$JOB######"
if [[ $? == 0 ]]; then 
    exit 0
fi

exit 1



