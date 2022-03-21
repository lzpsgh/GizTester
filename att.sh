#!/usr/bin/env bash
# set -o nounset #有未定义变量时退出
# set -o errexit #报错时退出
# set -o verbose #跟踪命令执行情况
# set -o xtrace  #跟踪命令执行情况并附加扩充信息

#set -eu
#set -o pipefail 
#set -x

# TODO
# 注意所有json文件的分号前后都不应该有空格，后面要规范，且脚本只处理分号前后不带空格的情况

function deployATT(){

	# 1. 配置cutwifi.sh
	local eth=`ip addr show | grep -e "inet[^6].*brd" | awk '{print $NF}'`
	sed -i "s/^idwifi=\".*\"/idwifi=\"${eth}\"/g" ${cutwifi_path}
	echo "idwifi的值已改为${eth}"
	echo "[ok]配置cutwifi.sh"

	# 2. 配置 common.json
	sed -i "s/\"mac\".*/\"mac\":\"${mac^^}\",/g" ${common_path} 
	local mac_end4=${mac:0-4}
	local rountssid="XPG-GAgent-${mac_end4,,}"
	sed -i "s/\"rountssid\".*/\"rountssid\":\"${rountssid}\",/g" ${common_path}
	# 方案A,简单粗暴
	# 方案A后续用抽象函数优化
#	sed -i "s/\"pk\".*/\"pk\":\"${pk}\",/g" ${common_path}
#	sed -i "s/\"productSecret\".*/\"productSecret\":\"${ps}\",/g" ${common_path}
#	sed -i "s/\"X-Gizwits-Enterprise-ID\".*/\"X-Gizwits-Enterprise-ID\":\"${eid}\",/g" ${common_path}
#	sed -i "s/\"X-Gizwits-Enterprise-Secret\".*/\"X-Gizwits-Enterprise-Secret\":\"${es}\",/g" ${common_path}
    # 方案B,备胎版
	local pk_mcu=`grep "^#define PRODUCT_KEY" ${mcu_protocol_path} | awk -F ' |/' '{print $3}'`
	local ps_mcu=`grep "^#define PRODUCT_SECRET" ${mcu_protocol_path} | awk -F ' |/' '{print $3}'`
	 if [[ "${pk}" != "${pk_mcu}" ]] ; then
	 	echo "[err]ATT中的pk是${pk}，MCU中的pk是${pk_mcu}，请核对"
	# fi
	echo "[ok]配置common.json"

	# 3. 配置rewritting.json 
	# 把ota用的bin文件放到otafile中,文件名格式为"GAgent_XXXXXXXX_XXXXXXXX_blablannn.bin"
	# 判断bin文件是否存在, 如不存在直接退出函数并提示
	# 如果存在软硬件版本都相同的不同文件怎么办
	cd ${ota_path};

	## 修改 GetModuleInfo
	# 如果在mac下调试,所有 sed -i 都要改为 sed -i "" .
    sed -i "s/\"hardVer\":\".*\"/\"hardVer\":\"${hard_ver}\"/g" ${rewriting_path}
    sed -i "s/\"softVer\":\".*\"/\"softVer\":\"${soft_ver}\"/g" ${rewriting_path}

	## 修改 GagentOTAonline-硬件版本号
    ## 默认是2个OTA文件的情况
    ## 建议此用例不要包含soft-ver和hard-ver
    ota_hard_ver=`ls GAgent* | awk -F '_' 'NR==1 {print $2}'`
    sed -i "s/\"hard_version\":\".*\"/\"hard_version\":\"${ota_hard_ver}\"/g" ${rewriting_path}

    ## 修改 GagentOTAonline-软件版本号-方法1 数组切片
     arr=`ls *${softVer}* | awk -F "_" '{print substr($3,0,8)}'`
     ota_soft_ver1=${arr[@]:0:8}会输出第一个
     ota_soft_ver2=${arr[@]:9:8}会输出第二个
	 sed -i "" "s/\"soft_version\":\".*\"/\"soft_version\":\"${ota_soft_ver1}\"/g" ${rewriting_path}
     sed -i "" "s/\"soft_version\":\".*\"/\"soft_version\":\"${ota_soft_ver2}\"/2g" ${rewriting_path}
    ### 修改 GagentOTAonline-软件版本号-方法2 AWK内置NR变量
    # substr在mac下是3,0,8,在linux下是3,0,9?
    ota_soft_ver1=`ls GAgent* | awk -F "_" 'NR==1 {print substr($3,0,9)}'`
    ota_soft_ver2=`ls GAgent* | awk -F "_" 'NR==2 {print substr($3,0,9)}'`
    sed -i "s/\"soft_version\":\".*\"/\"soft_version\":\"${ota_soft_ver1}\"/" ${rewriting_path}
    sed -i "s/\"soft_version\":\".*\"/\"soft_version\":\"${ota_soft_ver2}\"/" ${rewriting_path}
#     planB : $var is not supported
     sed -i '0, /\"soft_version\":\".*\"/s//\"soft_version\":\"\$ota_soft_ver1\"/' ${rewriting_path}
#     planC : fail
     sed '/soft_version/{x;s/^/./;/^.\{2\}$/{x;s/soft_version/ota_soft_ver2/;b};x}'
    
    ## 修改 GagentOTAonline-文件名
    # 这里name的分号前后有空格，暂不进行规范处理
    ota_name1="GAgent_${ota_hard_ver}_${ota_soft_ver1}"
    ota_name2="GAgent_${ota_hard_ver}_${ota_soft_ver2}"
#     bug name always = name1
    sed -i "s/\"name\" :\".*\"/\"name\" :\"${ota_name1}\"/" ${rewriting_path}
    sed -i "s/\"name\" :\".*\"/\"name\" :\"${ota_name2}\"/" ${rewriting_path}

	## 修改 M2M_ManageCMD
	# TODO 等抽象函数
	sed -i "s/\"product_key\":\".*\"/\"product_key\":\"${pk}\"/" ${rewriting_path}
	sed -i "s/\"productSecret\":\".*\"/\"productSecret\":\"${ps}\"/" ${rewriting_path}
	sed -i "s/\"enterprise_id\": \".*\"/\"enterprise_id\": \"${eid}\"/" ${rewriting_path}
	sed -i "s/\"enterprise_secret\": \".*\"/\"enterprise_secret\": \"${es}\"/" ${rewriting_path}

	echo "[err]配置rewritting.json"
	echo "[err]部分用例配置异常警告"

	# 4. 其他检查项
	# TEST 没有log目录时自动创建,到时要测试下执行后的pwd.   
	(cd ${ATT_HOME}/${mcu_dir}  && [[ ! -e log ]] && mkdir log)
	(cd ${ATT_HOME}/${mod_dir} && [[ ! -e log ]] && mkdir log)
	echo "[ok]检查MCU用例开关: "
	grep MCUOTA ${vitalcase_path} #| awk -F ':' '{print $2}'
	echo "[ok]检查OTA用例开关: "
	grep BigData ${vitalcase_path} #| awk -F ':' '{print $2}'

	local uart_local=`ls /dev/ttyUSB*`  # /dev/ttyUSB0
	local uart_expect=`grep -e "^#define UARTNAME" ${mcu_product_path} | awk -F " |\"" '{print $4}'`
	if [[ "${uart_local}" != "${uart_expect}" ]] ; then
    	echo "[err]本地与头文件中定义的tty号不一致，请检查"
    	echo "[err]本地:${uart_local}, 头文件:${uart_expect}"
	elif [[ ${uart_local_number} -eq 3 ]] ; then 
		echo 'test'
    else 
    	echo "[ok]检查tty号一致: ${uart_local}"
    fi
    #changeJsonValue moduleType 4 rewriting_path
	echo "[ok]脚本配置检查 完成"
}

function cleanLog(){
	cd ${ATT_HOME}/${mod_dir} && [[ -e log ]] && rm -f ./log/*.txt
	cd ${ATT_HOME}/${mcu_dir} && [[ -e log ]] && rm -f ./log/*.txt
	echo "[ook]日志清除- 完成"
}

function runATT(){
	# test文件和gDev文件不存在的情况暂不处理
	# gnome-terminal只针对Gnome用户,其他桌面环境待后续适配
	[[ -z `which gnome-terminal` ]] && echo "[err]启动ATT失败，请检查gnome-terminal命令是否正常" && return
	# module_dir= (${mode} -eq 1)?"${mod_dir}":"${mod_dir}"
	$(gnome-terminal -x bash -c "cd ${ATT_HOME}/${mod_dir}; echo ${user_pwd}|sudo -S ./test; exec bash")
	$(gnome-terminal -x bash -c "cd ${ATT_HOME}/${mcu_dir}; echo ${user_pwd}|sudo -S ./objs/gDev; exec bash")
	echo "[ok]开始运行ATT"
}

function backupLog(){
	cd ${ATT_HOME}
	logname="${hard_ver}-${soft_ver}-${flash}`date '+%m%d%H%M%S'`"
	[[ ! -f ${logname} ]] && mkdir -m 755 ${logname}
	ALOG_HOME=${ATT_HOME}/${logname}

	# TODO log文件夹不存在时
	cd ${ATT_HOME}/${mcu_dir}/log && mcu_last_log=`ls -r | head -n 1` 
	[[ ! -z ${mcu_last_log} ]] && echo ${user_pwd} |sudo -S chmod 755 ${mcu_last_log} && cp ${mcu_last_log} ${ALOG_HOME} && echo "[ok]已拷贝 mcu 最新日志" 

	cd ${ATT_HOME}/${mod_dir}/log && wifi_last_log=`ls -r | head -n 1`
	[[ ! -z ${wifi_last_log} ]] && echo ${user_pwd} |sudo -S chmod 755 ${wifi_last_log} && cp ${wifi_last_log} ${ALOG_HOME} && echo "[ok]已拷贝 模组 最新日志"
	cd ${ATT_HOME}/${mod_dir}
	[[ -f GizSDKLogFile.sys ]]  && echo ${user_pwd} |sudo -S chmod 755 GizSDKLogFile.sys && cp GizSDKLogFile.sys ${ALOG_HOME} && echo "[ok]已拷贝 daemon 最新日志"

	echo "[ok]日志备份 完成,路径是: ${ALOG_HOME}"
}

function help(){
	cat <<- EOF	
	【使用方法】
	自动配置: att d (执行前先改好main函数的参数，但OTA相关用例暂不支持)
	清理日志: att c (清理相关目录下时间最近的日志)
	执行测试: att r (自动运行 test 和 /objs/gDev)
	备份日志: att b (将mcu和att日志统一拷贝到另外目录中)
	EOF
}

# 调用sed抽象出函数
# changeJsonValue a b c
function changeJsonValue(){
	key=$1
	value=$2
	filepath=$3
	sed -i "" "s/\"${key}\":\".*\"/\"${key}\":\"${value}\"/g" ${filepath}
	# 注意执行后如果sed找不到key也不会返回失败,表现和替换成功一样
	echo "changeJsonValue ${key}的值修改为${value}" 
}

function pickOpt(){
	case "$1" in
		d)  deployATT ;;
		c)  cleanLog ;;  
		r)  runATT ;;  
		b)  backupLog ;;
		*)  help ;;
	esac
}

function f_man_pack
{
    cur_path=`pwd`
    index=(0 1 2 3 4 5)
    for i in ${index[*]}
    do
	path=${PATH_ARRAY[i]}        
        file_list=${FILE_ARRAY[i]}
        cd $path
        f_file_backup $file_list
        cd $cur_path
    done 
}

main(){
	# 执行sudo时的用户密码
	user_pwd="123"
	# 设备MAC或者IMEI
	mac="bcddc292023d"
	# 硬件版本号
	hard_ver="00ESP826"
	# 软件版本号
	soft_ver="04020036"
	# FLASH大小,一般只在乐鑫和汉枫上会区分
	flash="1M"
	# MCU目录名
	mcu_dir="MCU"
	# 模组目录名
	mod_dir="ATT_WIFI"

	# 这部分一般不需要改
	ATT_HOME=`pwd`
	cutwifi_path="${ATT_HOME}/${mod_dir}/cutwifi.sh"
	casefile_path="${ATT_HOME}/${mod_dir}/casefile"
	common_path="${ATT_HOME}/${mod_dir}/casefile/common.json"
	rewriting_path="${ATT_HOME}/${mod_dir}/casefile/rewriting.json"
	vitalcase_path="${ATT_HOME}/${mod_dir}/casefile/vitalcase"
	ota_path="${ATT_HOME}/${mod_dir}/otafile"
	mcu_product_path="${ATT_HOME}/${mcu_dir}/gizwits/gizwits_product.h"
	mcu_protocol_path="${ATT_HOME}/${mcu_dir}/gizwits/gizwits_protocol.h"
	mcu_gdev_path="${ATT_HOME}/${mcu_dir}/objs/gDev"
	# 这部分也不建议改,此pk为机智云平台端部QA-DDataTest_V,改了后用例里的数据点会失效. 同样企业id也不建议改
	pk="a5c353f5e2764a969122f811c8150e84"
	ps="37e2be12fdf1443f93c6f64203e9338a"
	eid="3ec4f26427444bdb8c585d5b615e29db"
	es="5ba82fe0952b40b39bcd3eb06d76a0f1"

	# 废弃
	# FILE_ARRAY=($BIN_LIST $CFG_LIST $ISOATM_LIST $LIB_LIST $WANGYIN_LIST $XMLHOST_LIST)
	# PATH_ARRAY=($FEEL_BIN "/home/feel/Online/cfg" "/home/feel/Online/cfg/xml/isoatm" $FEEL_LIB "/home/feel/Online/cfg/xml/wangyin" "/home/feel/Online/cfg/xml/xmlhost")

	pickOpt "$1"
}

main "$@"



# ========
#括指定lib目录下core所有的jar
# for tradePortalJar in ../apps/lib/core/*.jar;
# do
#    CLASSPATH="$CLASSPATH":"$tradePortalJar"
# done