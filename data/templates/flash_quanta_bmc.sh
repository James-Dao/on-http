#!/bin/bash
set -xe

#Raw Lan command to get BMC card type
getLanCommand=$(ipmitool raw 0x0C 0x02 0x01 0xFF 0x00 0x00)
echo $getLanCommand
array2=(${getLanCommand//$'\n'/ })
echo ${array2[0]}
bmcCardType=${array2[1]}
echo $bmcCardType

#Lan print command to get IP source info "Static Address"
lanPrintInfo=$(ipmitool lan print)
array3=(${lanPrintInfo//$'\n'/ })
ipSrcInfo=${array3[54]}
echo "${ipSrcInfo,,}"
ipaddrInfo=${array3[59]}
echo $ipaddrInfo
netMaskInfo=${array3[63]}
echo $netMaskInfo
defGatewayInfo=${array3[100]}
echo $defGatewayInfo

#Backup files
/opt/socflash/socflash_x64 -b /opt/uploads/bmc-backup.bin
curl -T /opt/uploads/bmc-backup.bin <%=filePath%>/<%=nodeId%>-bmc-backup.bin

#Flash BMC
/opt/socflash/socflash_x64 -s option=x flashtype=2 if=<%=downloadDir%>/<%=file%>
sleep 5

counter=90
until [ $counter -le 0 ]; do
    set +e
    check=$(sudo ipmitool mc info | grep -c 'Manufacturer ID')
    set -e
    if [ $check == 1 ]; then
        #Raw LAN command to set the BMC card type
        ipmitool raw 0x0C 0x01 0x01 0xFF $bmcCardType
        sleep 8
        #Raw LAN command to check if BMC card type was set correctly
        getLanCommand=$(ipmitool raw 0x0C 0x02 0x01 0xFF 0x00 0x00)
        array4=(${getLanCommand//$'\n'/ })
        bmcCardTypeCheck=${array4[1]}
        echo $bmcCardTypeCheck
        if [ $bmcCardTypeCheck != $bmcCardType ]; then
           echo "Check didn't pass, BMC card type wasn't set properly"
           exit 1;
        fi;
        sleep 2

        #IPMI tool command to set ipsrc to whatever is stored in ipSrcInfo (but in lower case)
        ipmitool lan set 1 ipsrc ${ipSrcInfo,,}
        sleep 8
        ipsrcCheck=$(ipmitool lan print)
        ipsrcCheck=(${ipsrcCheck//$'\n'/ })
        ipsrcCheck=${ipsrcCheck[54]}
        echo $ipsrcCheck
        if [ $ipsrcCheck != $ipSrcInfo ]; then
           echo "Check didn't pass, ip source wasn't set properly"
           exit 1;
        fi;
        sleep 2

        #IPMI tool command to set IP address
        ipmitool lan set 1 ipaddr $ipaddrInfo
        sleep 8
        ipaddrCheck=$(ipmitool lan print)
        ipaddrCheck=(${ipaddrCheck//$'\n'/ })
        ipaddrCheck=${ipaddrCheck[59]}
        echo "$ipaddrCheck"
        if [ $ipaddrCheck != $ipaddrInfo ]; then
           echo "Check didn't pass, ip address wasn't set properly"
           exit 1;
        fi;
        sleep 2

        #IPMI tool command to set net mask
        ipmitool lan set 1 netmask $netMaskInfo
        sleep 8
        netmaskCheck=$(ipmitool lan print)
        netmaskCheck=(${netmaskCheck//$'\n'/ })
        netmaskCheck=${netmaskCheck[63]}
        echo "$netmaskCheck"
        if [ ${netmaskCheck} != ${netMaskInfo} ]; then
           echo "Check didn't pass, netmask wasn't set properly"
           exit 1;
        fi;

        #IPMI tool command to set default gateway address
        ipmitool lan set 1 defgw ipaddr $defGatewayInfo
        sleep 8
        defgwCheck=$(ipmitool lan print)
        defgwCheck=(${defgwCheck//$'\n'/ })
        defgwCheck=${defgwCheck[100]}
        echo "$defgwCheck"
        if [ ${defgwCheck} != ${defGatewayInfo} ]; then
           echo "Check didn't pass, default gateway wasn't set properly"
           exit 1;
        fi;

        #Reboot BMC so that webUI can take effect
        ipmitool mc reset cold
        sleep 30
        set +e
        retry=30
        until [ $retry -le 0 ]; do
            ipmitool mc info
            if [ $? == 0 ]; then
                exit 0
            fi;
            sleep 1
            let retry-=1
        done
        set -e

        echo "BMC doesn't alive after update"
        exit 1
    fi
    sleep 1
    let counter-=1
done
echo "BMC is not responding after 90 tries, exiting script!!!"
exit 1
echo "Done"
