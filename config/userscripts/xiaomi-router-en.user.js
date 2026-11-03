// ==UserScript==
// @name         Xiaomi router: English
// @namespace    simple_nix
// @version      1.3
// @description  Translate the Xiaomi router's Chinese-only admin pages to English.
// @match        http://192.168.31.1/*
// @match        https://192.168.31.1/*
// @match        *://miwifi.com/*
// @match        *://router.miwifi.com/*
// @run-at       document-start
// @all-frames   true
// @grant        none
// ==/UserScript==

(function () {
  'use strict';

  // Chinese text -> English. A text (or attribute) is looked up whole first,
  // whitespace-normalized. Keys with {$name} are patterns: the placeholder
  // matches whatever the page filled in and is copied into the English.
  // Failing that, keys of 3+ characters (and those in PIECES_OK) are replaced
  // inside the text; if any Chinese is still left, the text stays as it was
  // (a half-translated sentence is worse than none).
  const DICT = {
    // ---- Login page
    '小米路由器': 'Xiaomi Router',
    'Redmi路由器': 'Redmi Router',
    '欢迎使用小米路由器': 'Welcome to Xiaomi Router',
    '扫描二维码，下载米家APP': 'Scan the QR code to get the Mi Home app',
    '随时随地管理你的路由器': 'Manage your router from anywhere',
    '使用小米WiFi APP管理您的路由器': 'Manage your router with the Xiaomi WiFi app',
    '易用': 'Easy',
    '全新小米WiFi APP 极简操作，享受生活': 'The new Xiaomi WiFi app: simple to use',
    '安全': 'Secure',
    '7x24小时安全防护 一键拉黑蹭网老王': '24/7 protection, block WiFi freeloaders in one tap',
    '加速': 'Fast',
    '提高带宽，游戏加速 团战胜人一筹': 'More bandwidth, faster gaming',
    '赚钱': 'Earn',
    '分享WiFi赚点钱 欢迎老王来蹭网': 'Share your WiFi and earn a little',
    '现在安装': 'Install now',
    '我已安装，现在打开': 'Already installed, open it',
    '本地管理小米路由器': 'Manage the router locally',
    '请输入路由器管理密码': 'Router admin password',
    '登录': 'Log in',
    '密码错误': 'Wrong password',

    // ---- Footer
    '官方网站': 'Official website',
    '官方微博': 'Weibo',
    '官方微信': 'WeChat',
    '用户社区': 'Community',
    '常见问题': 'FAQ',
    '服务热线': 'Support hotline',

    // ---- Header, top menu, router menu
    '路由状态': 'Status',
    '存储功能': 'Storage',
    '常用设置': 'Settings',
    '高级设置': 'Advanced',
    '添加Mesh子路由': 'Add Mesh node',
    '(家)': '(Home)',
    '（家）': ' (Home)',
    '家': 'Home',
    '修改路由器名称': 'Rename router',
    '系统升级': 'System update',
    '下载米家APP': 'Get the Mi Home app',
    '重启': 'Reboot',
    '注销': 'Log out',
    '路由器名称': 'Router name',
    '路由器位置': 'Router location',
    '位置': 'Location',
    '选择放置的位置': 'Choose where it stands',
    '客厅': 'Living room',
    '主卧': 'Main bedroom',
    '次卧': 'Second bedroom',
    '书房': 'Study',
    '厨房': 'Kitchen',
    '办公室': 'Office',
    '地下室': 'Basement',
    '卫生间': 'Bathroom',
    '阁楼': 'Attic',
    '阳台': 'Balcony',
    '餐厅': 'Dining room',
    'PC客户端': 'PC app',
    'MAC客户端': 'Mac app',
    '手机客户端': 'Phone app',
    '手机扫描二维码安装米家APP': 'Scan the QR code with your phone to install the Mi Home app',

    // ---- Reboot / shut down / reset
    '重启路由器': 'Reboot router',
    '关闭路由器': 'Shut down router',
    '路由器关机': 'Shut down router',
    '路由器重启需要等待十几秒或更多时间，重启过程中将会断开网络连接，稍后将自动重新连接网络。':
      'A reboot takes ten seconds or more. The network drops during the reboot and reconnects automatically.',
    '关闭路由器将断开其他设备的数据访问和网络连接，之后便可以安全的断开电源。（再次启动需要手工连接电源）':
      'Shutting down disconnects all devices; after that you can safely unplug the power. (To start it again, plug the power back in.)',
    '确定重启路由器，重启将断开和小米路由器的连接。': 'Reboot the router? This disconnects you from it.',
    '是否确定关闭路由器，操作将断开和小米路由器的连接。': 'Shut down the router? This disconnects you from it.',
    '关机中，请等待路由器指示灯熄灭后再断开电源': 'Shutting down. Wait for the router\'s light to go out before unplugging it.',
    '恢复出厂设置': 'Factory reset',
    '确定要恢复出厂设置让小米路由器回到初始状态？': 'Factory-reset the router to its initial state?',
    '重启中...': 'Rebooting...',
    '操作生效，等待设备重启...': 'Applied, waiting for the router to reboot...',
    '操作生效,重启成功！': 'Applied, reboot finished!',
    '自动连接路由器失败，请检查无线或者网线是否连接正确。':
      'Couldn\'t reconnect to the router. Check your Wi-Fi or cable connection.',
    ', 等待自动跳转... 用时{$time}秒': ', redirecting... {$time}s',

    // ---- Notices (green banner)
    '检测到最新版本为{$version}，': 'New firmware available: {$version}, ',
    '检测到最新版本为': 'New firmware available: ',
    '点击此处立即升级': 'update now',
    '你有新短信，': 'You have a new text message, ',
    '点击此处查看': 'click to view',
    '5G Wi-Fi启动失败，': '5 GHz Wi-Fi failed to start, ',
    '请联系小米客服解决': 'contact Xiaomi support',
    '检测到与上级路由器存在IP冲突，建议切换到': 'IP conflict with the upstream router. Switch to ',
    '有线中继模式': 'wired repeater mode',
    '或者': ' or ',
    '避让IP冲突': 'avoid the IP conflict',
    '短信箱已满，': 'Text message inbox is full, ',
    '请删除无用短信以保障短信功能正常': 'delete old messages to keep texting working',
    '检测到与上级路由器存在IP冲突，请': 'IP conflict with the upstream router. Please ',
    '修改局域网IP地址网段': 'change the LAN IP range',
    '检测到Mesh网络均为有线组网，': 'All Mesh nodes are wired, ',
    '您可以开放专有回程频段以获得更好的Wi-Fi体验': 'you can free the dedicated backhaul band for better Wi-Fi',
    '执行此操作，局域网IP将会变更为': 'This changes the LAN IP to ',
    '该过程无线网络会重启，将出现短暂掉线。': 'Wi-Fi restarts during this and drops briefly.',
    '此时5G网络已关闭': '5 GHz Wi-Fi is now off',
    '此时5G网络已打开': '5 GHz Wi-Fi is now on',

    // ---- Add Mesh node dialogs
    '您可以选择以下两种方式来新增Mesh子路由': 'There are two ways to add a Mesh node',
    '无线组网：': 'Wireless:',
    '1、将未配置过的路由器作为子路由，放置在需要Wi-Fi信号覆盖的房间 （如已配置请长按Reset按键5秒以上进行重置）':
      '1. Place an unconfigured router in the room that needs Wi-Fi (if it was set up before, hold its Reset button 5+ seconds to reset it)',
    '*请确保此路由器处于未配置状态，如已配置请长按Reset按键5秒以上进行重置':
      '*Make sure that router is unconfigured; if not, hold its Reset button 5+ seconds to reset it',
    '2、接通子路由电源，等待System指示灯变成蓝色或白色常亮（颜色取决于具体型号）':
      '2. Power it on and wait until its System light is steady blue or white (depends on the model)',
    '3、点击开始搜索': '3. Click Start search',
    '有线组网：': 'Wired:',
    '1、将未配置过的子路由WAN口与主路由LAN口通过网线连接':
      '1. Connect the new node\'s WAN port to this router\'s LAN port with a cable',
    '2、将子路由上电，启动完成后将自动进行组网，组网时子路由Internet指示灯快闪':
      '2. Power on the node; it joins automatically once booted (its Internet light blinks fast while joining)',
    '开始搜索': 'Start search',
    '温馨提示': 'Note',
    '为保证Mesh网络良好的使用体验，当前至多可支持10台Mesh路由器组网，更多Mesh路由器建议组成新的Mesh网络。':
      'For a good Mesh experience, up to 10 routers are supported per Mesh network; build a separate network for more.',
    '知道了': 'Got it',
    '添加Mesh节点': 'Add Mesh node',
    '搜索并添加Mesh节点时，请先到Wi-Fi设置页面，开启5G Wi-Fi。':
      'To search for and add Mesh nodes, first turn on 5 GHz Wi-Fi in Wi-Fi settings.',
    '去开启': 'Turn it on',
    '搜索要添加的Mesh子路由': 'Search for a Mesh node to add',
    '搜索Mesh子路由...': 'Searching for Mesh nodes...',
    '选择要添加的Mesh子路由': 'Choose the Mesh node to add',
    '请选择要添加的设备': 'Choose the device to add',
    '添加': 'Add',
    '重试': 'Retry',
    '未找到可用的Mesh子路由': 'No Mesh node found',
    '可以尝试以下方法：': 'Things to try:',
    '1、确认主路由与待添加的子路由均支持小米Mesh组网功能：':
      '1. Make sure both routers support Xiaomi Mesh:',
    '支持小米Mesh组网的路由产品': 'routers that support Xiaomi Mesh',
    '2、确保待添加的子路由处于未配置状态（长按Reset按钮5秒后即可恢复成未配置状态）;':
      '2. Make sure the new node is unconfigured (hold Reset 5 seconds to reset it);',
    '3、将待添加的子路由靠近主路由并重试（注意保持1米以外的距离以免干扰）；':
      '3. Move the new node closer to this router and retry (keep at least 1 m apart to avoid interference);',
    '4、将待添加的子路由升至最新固件，并重置后重试': '4. Update the new node\'s firmware, reset it and retry',
    '重新搜索': 'Search again',
    '正在扩展Mesh网络': 'Extending the Mesh network',
    '正在连接Mesh子路由...': 'Connecting to the Mesh node...',
    'Mesh网络扩展成功': 'Mesh network extended',
    '完成': 'Done',
    'Mesh网络扩展失败': 'Couldn\'t extend the Mesh network',
    '1、将待添加的子路由靠近主路由并重试（注意保持1米以外的距离以免干扰）；':
      '1. Move the new node closer to this router and retry (keep at least 1 m apart to avoid interference);',
    '2、将主路由升至最新固件版本；': '2. Update this router\'s firmware;',
    '3、将待添加的子路由升至最新固件，并重置后重试（长按Reset按钮5秒后即可重置）':
      '3. Update the new node\'s firmware, reset it and retry (hold Reset 5 seconds to reset)',
    '正在扩展Mesh节点(1-2分钟)...': 'Adding the Mesh node (1-2 minutes)...',
    '正在同步Mesh节点配置...': 'Syncing the Mesh node\'s settings...',
    '搜索并添加Mesh节点': 'Search and add Mesh nodes',
    '请放置在主路由1米以外': 'Place it more than 1 m from this router',
    '请靠近主路由': 'Move it closer to this router',
    '没有搜索到可用的mesh节点': 'No Mesh node found',

    // ---- Status page
    '终端设备': 'Devices',
    '互联网': 'Internet',
    '带宽': 'Bandwidth',
    '频段': 'band',
    'Wi-Fi名称': 'Wi-Fi name',
    'Wi-Fi密码': 'Wi-Fi password',
    '连接设备数量': 'Connected devices',
    '设置': 'Settings',
    '路由器型号': 'Router model',
    '系统ROM版本': 'ROM version',
    'MAC地址': 'MAC address',
    'Xiaomi路由器': 'Xiaomi Router ',
    '路由器': 'router',
    '稳定版': 'stable',
    '台': 'devices',

    // ---- Internet page
    '外网状态': 'internet status',
    '连接类型': 'Connection type',
    'IP地址': 'IP address',
    '网关地址': 'Gateway',
    '外网带宽': 'internet bandwidth',
    '下载带宽': 'Download bandwidth',
    '上传带宽': 'Upload bandwidth',
    '手工设置': 'Set manually',
    '手工设置外网带宽': 'Set internet bandwidth manually',
    '双WAN模式下，不支持在此处设置外网带宽': 'In dual-WAN mode, internet bandwidth can\'t be set here',
    '上传': 'Upload',
    '下载': 'Download',
    '系统版本': 'System version',

    // ---- Devices page
    '网线连网设备': 'Wired devices',
    '无线连网设备': 'Wi-Fi devices',
    '访问外网': 'Internet access',
    '本机': 'this computer',

    // ---- Storage page
    '存储设置': 'Storage settings',
    '未检测到存储设备，请将USB存储设备连接到你的小米路由器': 'No storage found. Plug a USB drive into the router.',
    '路由器USB3.0使用时会对2.4G WiFi有一定影响，如有需要可关闭USB3.0，系统将为您切换至USB2.0模式。（USB2.0对2.4G WiFi没有影响）':
      'USB 3.0 interferes somewhat with 2.4 GHz Wi-Fi. If that matters, turn USB 3.0 off and the router switches to USB 2.0 mode (USB 2.0 doesn\'t affect 2.4 GHz Wi-Fi).',
    '如何使用Samba功能？': 'How to use Samba?',
    'Samba功能': 'Samba (file sharing)',
    '第一步：支持Samba协议的PC或电视连入此路由提供的网络；':
      'Step 1: connect a PC or TV that supports Samba to this router\'s network;',
    '第二步：根据接入终端的情况进行文件访问': 'Step 2: open the files from that device',
    'PC：打开文件资源管理器，输入\\\\': 'PC: open the file manager and enter \\\\',
    '或\\\\': 'or \\\\',
    '，回车后即可访问此路由器外接存储器上的文件': ', press Enter to see the files on the router\'s USB drive',
    '电视：找到此电视上的Samba入口，根据电视操作提示进行访问此路由器外接存储器上的共享文件':
      'TV: find the TV\'s Samba entry and follow its prompts to open the shared files on the router\'s USB drive',
    '*注：部分设备在Samba访问时需要额外的网络凭据，请尝试在用户名输入栏处输入guest，密码输入栏留空尝试连接。如问题仍无法解决，请联系客服处理。':
      '*Note: some devices ask for network credentials. Try user name "guest" with an empty password. If that doesn\'t help, contact support.',
    '开启Samba功能后，可以让所有接入此路由器支持Samba协议的终端设备在局域网中访问路由器或其外接U盘/移动硬盘上的共享文件。':
      'With Samba on, every device on this network that supports Samba can open the shared files on the router\'s USB stick or drive.',
    'USB3.0': 'USB 3.0',
    '虚拟内存': 'Virtual memory (swap)',
    '该路由器可通过创建虚拟内存来调用外部存储资源充当内存。':
      'The router can use external storage as extra memory (swap).',
    '使用方法：将剩余空间大于2GB的U盘或者移动硬盘（推荐NTFS/FAT32/exFAT/EXT4等主流格式）插入此路由USB接口，路由器识别到此存储设备后，选择预扩展内存大小来创建虚拟内存。':
      'How: plug a USB stick or drive with more than 2 GB free (NTFS/FAT32/exFAT/EXT4 recommended) into the router. Once the router sees it, choose a size and create the swap.',
    '*注：在创建虚拟内存过程中若Docker服务正在运行，Docker服务将会被重启。在虚拟内存使用过程中，请勿直接拔出磁盘，如需拔出磁盘，请使用安全移除磁盘功能。':
      '*Note: if Docker is running while the swap is created, Docker restarts. While swap is in use, don\'t just pull the drive out; use Safely remove.',
    '虚拟内存大小': 'Swap size',
    '创建虚拟内存': 'Create swap',
    '当前路由器内存状态': 'Router memory',
    '当前内存占用：': 'Memory in use: ',
    '路由器内存容量:': 'Router memory: ',
    '当前虚拟内存状态': 'Swap status',
    '虚拟内存容量:': 'Swap size: ',
    '删除虚拟内存': 'Delete swap',
    '分区名称': 'Partition',
    '已用': 'Used',
    '/ 总容量': '/ total',
    '总容量': 'total',
    '外接存储器格式:': 'Drive format: ',
    '安全移除磁盘': 'Safely remove',
    '下一步': 'Next',
    '执行此操作将删除与路由器直连的存储器中扩展的虚拟内存，如果此时Docker服务正在运行，Docker服务将会被重启':
      'This deletes the swap on the router\'s USB drive. If Docker is running, it restarts.',
    '虚拟内存创建中...': 'Creating swap...',
    '虚拟内存创建中': 'Creating swap',
    '虚拟内存删除中...': 'Deleting swap...',
    '设置成功！请等待一段时间完成虚拟内存创建': 'Saved! Creating the swap takes a while.',
    '1.创建期间请勿断电或拔插存储设备;': '1. Don\'t cut power or unplug the drive while it\'s being created;',
    '2.使用过程中，如需拔出磁盘请使用安全移除磁盘功能，强行拔出可能会导致路由器工作异常甚至重启;':
      '2. To unplug the drive, use Safely remove; pulling it out can make the router misbehave or reboot;',
    '虚拟内存创建失败，未检测到可用的外接存储器': 'Couldn\'t create swap: no usable USB drive found',
    '存储位置选择': 'Choose the drive',
    '虚拟内存创建失败，未检测到满足大小的外接存储器': 'Couldn\'t create swap: no USB drive with enough free space',
    '虚拟内存创建失败，请确保与路由器直连的存储器剩余空间大于将要创建的虚拟内存值':
      'Couldn\'t create swap: the USB drive needs more free space than the swap size',
    '虚拟内存删除成功！': 'Swap deleted!',
    '虚拟内存删除失败': 'Couldn\'t delete swap',
    '移除成功': 'Removed',
    '移除失败': 'Couldn\'t remove',
    '是否确认移除？': 'Remove it?',
    '移除': 'Remove',
    '移除{$dev}将会一并移除此U盘的所有分区，请确认': 'Removing {$dev} also removes all partitions on this USB drive. Continue?',
    '设置成功，请等待{$t}s完成USB模式切换': 'Saved. Switching USB mode, wait {$t}s',

    // ---- Docker page
    '此路由器支持安装Docker到直连的存储设备中，请插入EXT4格式的USB存储设备，之后点击安装Docker按钮下载Docker文件到此存储设备中。':
      'The router can install Docker onto a USB drive plugged into it. Plug in an EXT4-formatted USB drive, then click Install Docker to download Docker onto it.',
    '注意：': 'Note:',
    '1.建议先开启虚拟内存扩展空间，再安装Docker': '1. Create swap first, then install Docker',
    '2.Docker运行前如果开启了虚拟内存，使用过程中不建议关闭虚拟内存或者更换USB存储设备':
      '2. If swap was on before Docker started, don\'t turn swap off or swap the USB drive while Docker is in use',
    '安装Docker': 'Install Docker',
    '如何使用Docker': 'How to use Docker',
    '如何使用Docker？': 'How to use Docker?',
    '运行Docker': 'Run Docker',
    'Docker安装成功后，需要通过安装第三方管理来对它进行使用和管理。':
      'After Docker is installed, install the third-party manager to use and manage it.',
    '1.单击安装第三方管理按钮，此时会进行第三方管理工具的安装；':
      '1. Click Install manager to install the third-party management tool;',
    '2.管理工具安装成功后，单击管理Docker按钮，网页会跳转至第三方管理工具，此页面集成了容器、镜像的基本操作功能和信息展示、管理等功能。':
      '2. Once it\'s installed, click Manage Docker. That opens the tool, where you can view and manage containers and images.',
    '安装第三方管理': 'Install manager',
    '管理Docker': 'Manage Docker',
    '卸载Docker': 'Uninstall Docker',
    '未检测到': 'Not found',
    '可用': 'Available',
    '（默认用户名：admin 密码：admin）': '(default user: admin, password: admin)',
    '不可用，请先运行docker并安装第三方管理': 'Unavailable; run Docker and install the manager first',
    'Docker文件安装中，请勿拔出与路由器相连的存储器': 'Installing Docker. Don\'t unplug the router\'s USB drive.',
    '第三方管理安装中，请勿拔出与路由器相连的存储器': 'Installing the manager. Don\'t unplug the router\'s USB drive.',
    '执行此操作将会安装docker文件到EXT4格式与此路由器直连的存储器中， 请确认是否继续进行？(推荐创建在已扩展虚拟内存的存储位置上)':
      'This installs Docker onto the router\'s EXT4 USB drive. Continue? (Best on the drive that holds the swap.)',
    'Docker安装': 'Docker install',
    'Docker卸载': 'Docker uninstall',
    '卸载超时，请稍候重试': 'Uninstall timed out, try again later',
    '安装超时，请稍候重试': 'Install timed out, try again later',
    '安装成功！': 'Installed!',
    '安装失败！': 'Install failed!',
    '未检测到可用的外接存储器，请确保分区格式为EXT4且可用容量大于32GB':
      'No usable USB drive found. It needs an EXT4 partition with more than 32 GB free.',
    '是否确认卸载？': 'Uninstall it?',
    '网络异常，请检查是否联网': 'Network error, check the internet connection',
    '已取消安装': 'Install canceled',

    // ---- Settings submenu
    'Wi-Fi设置': 'Wi-Fi',
    '上网设置': 'Internet',
    '安全中心': 'Security',
    '局域网设置': 'LAN',
    '系统设置': 'System',

    // ---- Wi-Fi settings page
    'Wi-Fi多频合一': 'Merge Wi-Fi bands (one name)',
    '开启后，2.4GHz和5GHz将合并显示为同一个名称，路由器将优先为终端选择最佳Wi-Fi网络。合并名称后部分终端可能离线，需重新连接。':
      'When on, 2.4 GHz and 5 GHz share one network name and the router picks the best band for each device. Some devices may drop off after merging and need to reconnect.',
    'Wi-Fi模式切换': 'Wi-Fi mode',
    '双频模式：具有更好的覆盖能力，适合大部分的应用场景。': 'Dual-band mode: better coverage, suits most uses.',
    '三频模式：覆盖弱于双频。可支持WiFi7手机双5G MLO并联，大幅提升带宽。同时可作为独立电竞频段，减少其他设备干扰。':
      'Tri-band mode: less coverage than dual-band. Lets Wi-Fi 7 phones use two 5 GHz links at once (MLO) for much more bandwidth, and can serve as a separate gaming band with less interference.',
    '工作模式': 'Mode',
    '双频模式': 'Dual-band',
    '三频模式': 'Tri-band',
    '访客Wi-Fi': 'Guest Wi-Fi',
    'Wi-Fi 5 兼容模式': 'Wi-Fi 5 compatibility mode',
    '某些老设备对Wi-Fi6协议支持不好，可能扫描不到信号或者连接不上等。开启此开关后，将会切换到Wi-Fi5模式，解决兼容问题。但同时会关闭Wi-Fi6的相关功能，如OFDMA、TWT、BSS Coloring等。':
      'Some old devices handle Wi-Fi 6 poorly: they may not see the network or can\'t connect. This switches to Wi-Fi 5 mode to fix that, but turns off Wi-Fi 6 features such as OFDMA, TWT and BSS Coloring.',
    'TWT节能模式': 'TWT power saving',
    'TWT节能模式兼容性问题解决办法': 'Fixing TWT power-saving problems',
    // the page glues this onto the (already translated) TWT label
    '兼容性问题解决办法': ': fixing compatibility problems',
    '如果出现老旧终端在此路由开启TWT节能模式后出现兼容性问题，建议尝试以下方法：':
      'If old devices have problems after TWT power saving is turned on, try this:',
    '1. 到相应终端制造商官网下载更新驱动；': '1. Get updated drivers from the device maker\'s website;',
    '2. 若最新驱动仍无法解决兼容性问题，建议先关闭该功能。': '2. If the latest drivers don\'t help, turn this feature off.',
    '开启TWT节能模式后，可通过TWT节能技术降低接入此路由器的Wi-Fi6终端设备功耗，部分老旧终端可能会有兼容性问题。':
      'TWT power saving lowers the power use of Wi-Fi 6 devices on this router. Some old devices may have compatibility problems.',
    '注：检测到已开启Wi-Fi5兼容模式，无法打开TWT开关。': 'Note: Wi-Fi 5 compatibility mode is on, so TWT can\'t be turned on.',
    'MU-MIMO“多用户多入多出”技术，可以让路由器与多台终端同时通信，极大改善无线资源利用效率，提升Wi-Fi体验。该功能生效需要路由器和终端同时支持。':
      'MU-MIMO (multi-user MIMO) lets the router talk to several devices at once, using airtime much more efficiently. Both the router and the device must support it.',
    '畅快连': 'Quick Connect',
    '开启此功能，路由器可自动发现支持畅快连的未初始化Wi-Fi设备，通过米家APP快速配网；修改路由器密码也将自动同步给支持畅快连的设备。':
      'When on, the router finds new Wi-Fi devices that support Quick Connect so you can set them up quickly in the Mi Home app; router password changes are also synced to them.',
    '选项': 'options',
    '开关': 'On/off',
    '开启': 'On',
    '名称': 'Name',
    '隐藏网络不被发现': 'Hide network',
    '加密方式': 'Encryption',
    '超强加密(WPA3个人版)': 'Strongest (WPA3 Personal)',
    '强混合加密(WPA3/WPA2个人版)': 'Strong mixed (WPA3/WPA2 Personal)',
    '强加密(WPA2个人版)': 'Strong (WPA2 Personal)',
    '混合加密(WPA/WPA2个人版)': 'Mixed (WPA/WPA2 Personal)',
    '无加密(允许所有人连接)': 'None (anyone can connect)',
    '密码': 'Password',
    '信号强度': 'Signal strength',
    '穿墙': 'High (through walls)',
    '标准': 'Standard',
    '节能': 'Low (power saving)',
    '无线信道': 'Channel',
    '频宽': 'Channel width',
    '该信道属于DFS信道，当与不支持DFS信道的设备组网时，可能导致组网失败，是否继续？':
      'This is a DFS channel. Mesh with devices that don\'t support DFS channels may fail. Continue?',
    '继续': 'Continue',
    '此信道受法规管控功率低于其他信道，为保障上网体验建议选择其他信道，是否继续？':
      'By regulation this channel has lower power than others; another channel is recommended. Continue?',
    '设置成功正在重启，遵照国家法律法规，路由器正在做退避雷达信号探测，Wi-Fi信号要{$n}s后才能开启，请稍候...':
      'Saved, restarting. By law the router must first scan for radar; Wi-Fi comes back in {$n}s, please wait...',
    '1.该操作将重启Wi-Fi并导致Wi-Fi下的所有设备失去连接；': '1. This restarts Wi-Fi and disconnects every Wi-Fi device;',
    '2.关闭5GHz Wi-Fi，将无法添加子Mesh节点；': '2. With 5 GHz Wi-Fi off, Mesh nodes can\'t be added;',
    '是否确认修改？': 'Apply the change?',
    '注：检测到已开启Wi-Fi5兼容模式，无法打开MLO开关。': 'Note: Wi-Fi 5 compatibility mode is on, so MLO can\'t be turned on.',
    '注：检测到未开启Wi-Fi多频合一，无法打开MLO开关。': 'Note: MLO needs "Merge Wi-Fi bands" on.',
    '检测到未启用Wi-Fi多频合一，无法打开MLO开关。': 'MLO needs "Merge Wi-Fi bands" on.',
    '关闭MLO多链路加速将会重启Wi-Fi模块，此期间所有接入此路由器的设备都会断开Wi-Fi连接，请确认是否继续。':
      'Turning off MLO restarts Wi-Fi; every Wi-Fi device on this router disconnects. Continue?',
    'MLO多链路加速': 'MLO multi-link boost',
    '修改Wi-Fi设置': 'Change Wi-Fi settings',
    '修改 Wi-Fi 设置': 'Change Wi-Fi settings',
    '设置成功，请等待{$time}秒完成模式切换': 'Saved. Switching mode, wait {$time}s',
    '仅支持WPA加密方式的设备将无法连接': 'Devices that only support WPA won\'t be able to connect',
    'WPA3为新一代加密技术，可使安全性大大加强，但选择该选项后部分旧设备会存在兼容性问题而无法接入':
      'WPA3 is the newest, much more secure encryption, but some older devices can\'t connect with it',
    '160MHz频宽只适用于36至64信道，系统将自动为您切换至80MHz频宽': '160 MHz width only works on channels 36-64; switching to 80 MHz',
    '160MHz频宽只适用于36至64信道，系统将自动为您切换至36信道': '160 MHz width only works on channels 36-64; switching to channel 36',
    '当前频宽不支持将要切换的信道，系统已自动选择可用的频宽':
      'The current width doesn\'t support that channel; a working width was chosen automatically',
    '自动': 'Auto',
    '自动 ({$ch})': 'Auto ({$ch})',
    '你手工选择的当前信道有可能造成部分机型较旧的设备无法连接': 'The channel you picked may keep some older devices from connecting',
    '推荐使用自动(80M)频宽，以获得更好的覆盖及抗干扰性能': 'Auto (80 MHz) width is recommended for better coverage and less interference',
    '少数设备可能不支持中文或特殊字符': 'A few devices may not support Chinese or special characters',
    'WiFi双频合一关闭，5GHz会默认使用2.4GHz相同的网络名称（加后缀_5G）和密码，如需设成不一样，请进行修改。':
      'With bands not merged, 5 GHz uses the 2.4 GHz name (plus _5G) and password by default; change them if you want them different.',
    'WiFi多频合一关闭，5GHz和5GHz-Game Wi-Fi会默认使用2.4GHz相同的网络名称（加后缀）和密码，如需设成不一样，请进行修改。':
      'With bands not merged, 5 GHz and 5 GHz-Game use the 2.4 GHz name (plus a suffix) and password by default; change them if you want them different.',
    'WiFi多频合一关闭，5GHz和5GHz-2 Wi-Fi会默认使用2.4GHz相同的网络名称（加后缀）和密码，如需设成不一样，请进行修改。':
      'With bands not merged, 5 GHz and 5 GHz-2 use the 2.4 GHz name (plus a suffix) and password by default; change them if you want them different.',
    '该操作将重启 Wi-Fi 并导致 Wi-Fi 下的所有设备失去连接，是否确认修改？': 'This restarts Wi-Fi and disconnects every Wi-Fi device. Apply?',
    '该修改会导致路由器重启，所有设备会短暂失去连接，是否确认修改？': 'This reboots the router; all devices lose connection briefly. Apply?',
    '三频模式覆盖明显弱于双频模式，该修改会导致路由器重启，所有设备会短暂失去连接，是否确认修改？':
      'Tri-band covers noticeably less than dual-band. This reboots the router; all devices lose connection briefly. Apply?',
    'Wi-Fi 信号强度设置': 'Wi-Fi signal strength',
    '设置已经生效，等待30秒后 Wi-Fi 重启。': 'Applied. Wi-Fi restarts in 30 seconds.',
    '你什么都没改变，提交什么啊': 'Nothing changed, nothing to save',
    '切换国家或地区将会变更路由器的无线网络工作信道，需要重启后生效，是否确定？':
      'Changing the country/region changes the Wi-Fi channels and needs a reboot. Continue?',
    '切换国家或地区': 'Change country/region',

    // ---- Internet settings page (WAN)
    '上网信息': 'Connection info',
    '正在检测上网连接方式，请稍等...': 'Detecting the connection type, please wait...',
    'IPv4信息': 'IPv4 info',
    'IPv6信息': 'IPv6 info',
    '账户：': 'Account: ',
    '子网掩码：': 'Subnet mask: ',
    '默认网关：': 'Default gateway: ',
    '问题排查': 'Troubleshooting',
    '宽带拨号帐号密码输入错误': 'Wrong broadband (PPPoE) account or password',
    '请检查帐号密码是否输入正确': 'Check the account and password',
    'PPPOE设置页面': 'PPPoE settings',
    '宽带因欠费无法继续使用': 'Broadband suspended for an unpaid bill',
    '联系运营商查询宽带是否欠费': 'Ask your provider whether the bill is paid',
    '宽带运营商机房故障': 'Provider equipment failure',
    '联系运营商了解是否当地有线路故障': 'Ask your provider about local line problems',
    '拨号状态异常': 'Dial-up error',
    '办法1:尝试关闭调制解调器(猫)和路由器，几分钟后重新通电再次尝试拨号':
      'Fix 1: turn off the modem and the router, wait a few minutes, power them on and dial again',
    '办法2:使用电脑或者旧路由器完成拨号，然后手工选择“结束连接”或“关闭连接”，再尝试使用Redmi路由器拨号。':
      'Fix 2: dial with a computer or the old router, then choose "End connection" or "Close connection", then dial with this router',
    '办法3:尝试在路由器上网设置中进行mac地址克隆，然后重新拨号': 'Fix 3: clone the MAC address in Internet settings, then dial again',
    'MAC地址克隆设置': 'MAC address clone settings',
    '办法4:尝试调整WAN口协商速率，然后重新拨号': 'Fix 4: change the WAN port link speed, then dial again',
    'WAN口协商速率设置': 'WAN port link speed settings',
    '更换了接入宽带': 'Changed broadband provider',
    '检查WAN口接入的宽带是否已经变更': 'Check whether the line on the WAN port changed',
    '静态IP': 'Static IP',
    '上网方式': 'Connection type',
    '账号': 'Account',
    '自动配置': 'Automatic',
    '手动配置': 'Manual',
    '特殊拨号': 'Special dial-up',
    '字节（网络正常情况下不建议修改）': 'bytes (leave it unless you have problems)',
    '服务名': 'Service name',
    '自动配置DNS': 'Automatic DNS',
    '手动配置DNS': 'Manual DNS',
    '必填': 'required',
    '子网掩码': 'Subnet mask',
    '网关': 'Gateway',
    '选填': 'optional',
    'MAC地址克隆': 'MAC address clone',
    '当前使用的MAC地址是': 'MAC address in use',
    '当前管理终端的MAC地址，可以手动更改为其他MAC地址': 'The MAC address of this computer; you can type a different one',
    '克隆': 'Clone',
    '恢复': 'Restore',
    '工作模式切换': 'Operating mode',
    '在路由器工作模式和中继工作模式之间进行切换': 'Switch between router mode and repeater mode',
    '切换': 'Switch',
    '请手工选择需要的工作模式': 'Choose the operating mode',
    '普通路由器工作模式（创建一个无线网络）': 'Router mode (creates a Wi-Fi network)',
    '无线中继工作模式（扩展现有的无线网络）': 'Wireless repeater mode (extends an existing Wi-Fi network)',
    '有线中继工作模式（扩展现有的网络）': 'Wired repeater mode (extends an existing network)',
    '正在设置中，请稍候...': 'Applying, please wait...',
    '请不要关闭浏览器或断开路由器': 'Don\'t close the browser or unplug the router',
    '请选择要扩大范围的无线网络': 'Choose the Wi-Fi network to extend',
    '选择网络': 'Choose network',
    '正在扫描附近的无线网络': 'Scanning for nearby Wi-Fi networks',
    '网络名称': 'Network name',
    '输入密码': 'Enter password',
    '手工输入网络名称': 'Enter the network name by hand',
    '无线网络的名称密码与目标路由器一致': 'Use the same Wi-Fi name and password as the main router',
    '设置WiFi名称和密码': 'Set Wi-Fi name and password',
    'WiFi名称': 'Wi-Fi name',
    'WiFi密码': 'Wi-Fi password',
    '找不到要中继的网络': 'Can\'t find the network to repeat',
    '请确认主路由器和中继路由器的Wi-Fi均已开启。': 'Make sure Wi-Fi is on on both the main router and this one.',
    '一键无线中继': 'One-click wireless repeater',
    '恭喜，小米路由器一键中继设置成功！': 'Done! The router is now a wireless repeater.',
    '1. 当前无线网络名称为：': '1. Wi-Fi network name: ',
    '2. 当前小米路由器的IP地址为：': '2. Router IP address: ',
    '当前工作模式切换为普通路由器会恢复为之前路由器的所有设置': 'Switching back to router mode restores all your previous router settings',
    '是否确定切换路由器的工作模式？': 'Switch the router\'s operating mode?',
    '恭喜，小米路由器切换为普通路由器工作模式成功！': 'Done! The router is back in router mode.',
    '3. 用miwifi.com也可以访问路由器管理页面': '3. miwifi.com also opens the router admin page',
    '有线中继工作模式说明': 'About wired repeater mode',
    '1.请确保小米路由器的WAN口与旧路由器通过网线连接': '1. Connect this router\'s WAN port to the old router with a cable',
    '2.旧路由器与小米路由处于同一局域网中，可以互访': '2. The old router and this one are on the same LAN and can reach each other',
    '3.中继模式下部分功能和插件将被屏蔽': '3. Some features and plugins are disabled in repeater mode',
    '恭喜，小米路由器一键有线中继模式设置成功！': 'Done! The router is now a wired repeater.',
    '新建的有线中继无线网络名称为': 'New repeater Wi-Fi name: ',
    '小米路由器的管理后台IP为': 'Router admin IP: ',
    '提示：中继模式下部分功能和插件将被屏蔽': 'Note: some features and plugins are disabled in repeater mode',
    '系统检测你的路由器未接入网线，请接好网线并继续': 'No cable detected. Plug in the cable and continue.',
    '我已接好网线，继续': 'Cable plugged in, continue',
    '放弃': 'Give up',
    '无线中继模式下，暂不支持Mesh组网。': 'Mesh isn\'t supported in wireless repeater mode.',
    '若当前已完成Mesh组网，将自动断开。': 'An existing Mesh network will be disconnected.',
    'IPV6网络设置': 'IPv6 settings',
    '启用此功能后，小米路由器将开启IPv6上网功能（使用前请咨询网络运营商是否支持IPv6）':
      'Turns on IPv6 internet (check first that your provider supports IPv6)',
    '静态IPv6': 'Static IPv6',
    '防火墙': 'Firewall',
    'WAN IPv6地址': 'WAN IPv6 address',
    'WAN IPv6地址前缀长度默认为128位': 'The WAN IPv6 prefix length defaults to 128',
    'WAN IPv6网关': 'WAN IPv6 gateway',
    'LAN IPv6前缀': 'LAN IPv6 prefix',
    'LAN IPv6前缀长度': 'LAN IPv6 prefix length',
    '适用于没有给路由分配IPv6前缀的上网环境，例如：上级光猫拨号':
      'For connections that don\'t give the router an IPv6 prefix, e.g. when the fiber modem dials',
    'WAN口选择': 'WAN port',
    '模式': 'Mode',
    '固定WAN口': 'Fixed WAN port',
    '智能选择WAN口（推荐）': 'Pick the WAN port automatically (recommended)',
    '接入到运营商宽带的网线可以插在任意网口': 'The internet cable can go into any port',
    'LAN口聚合': 'LAN port aggregation',
    '不同形态的网口不能聚合，比如1G网口不能和2.5G网口聚合': 'Ports of different speeds can\'t be combined, e.g. 1G with 2.5G',
    '将两个LAN口聚合，实现网口速率叠加': 'Combine two LAN ports to add up their speed',
    '请选择需要聚合的两个LAN口': 'Choose the two LAN ports to combine',
    'WAN IPv6地址：': 'WAN IPv6 address: ',
    'WAN IPv6网关：': 'WAN IPv6 gateway: ',
    'LAN IPv6地址：': 'LAN IPv6 address: ',
    'LAN IPv6前缀：': 'LAN IPv6 prefix: ',
    '断开': 'Disconnect',
    '立即连接': 'Connect now',
    '1.如果您已开启访客wifi，切换为无线中继模式后，访客wifi将会关闭': '1. Guest Wi-Fi turns off in wireless repeater mode',
    '2.切换为无线中继模式后，Mesh功能将不可用': '2. Mesh isn\'t available in wireless repeater mode',
    '如果您已开启访客wifi，切换为有线中继模式后，访客wifi将会关闭': 'Guest Wi-Fi turns off in wired repeater mode',
    '网络密码': 'Network password',
    '前缀': 'Prefix',
    '前缀长度': 'Prefix length',
    '联网方式设置': 'Connection settings',
    '联网方式设置中，请稍等...': 'Applying connection settings, please wait...',
    'IPv6网络方式设置': 'IPv6 settings',
    'IPv6网络方式设置中，请稍等...': 'Applying IPv6 settings, please wait...',
    '正在拨号...': 'Dialing...',
    '拨号成功': 'Connected',
    '拨号失败': 'Dial-up failed',
    '，正在尝试特殊拨号模式...': ', trying special dial-up mode...',
    '已断开': 'Disconnected',
    '获取失败,': 'Couldn\'t get it, ',
    '经过检测，建议使用PPPoE方式(需要输入帐号与密码)': 'Detected: use PPPoE (needs an account and password)',
    '经过检测，建议使用DHCP方式(系统自动分配IP地址)': 'Detected: use DHCP (the address is assigned automatically)',
    '经过检测，建议使用静态IP方式': 'Detected: use a static IP',
    '经过检测，你的WAN口无法连通，可能网线没插好': 'The WAN port has no connection; the cable may be loose',
    '经过检测，无法识别你的上网类型，请手工选择上网方式': 'Couldn\'t detect the connection type; choose it by hand',
    '该MAC地址与WAN1口MAC地址冲突，请输入其他MAC地址': 'That MAC address clashes with WAN1\'s; enter another',
    '该MAC地址与WAN2口MAC地址冲突，请输入其他MAC地址': 'That MAC address clashes with WAN2\'s; enter another',
    '该MAC地址与当前使用的MAC地址相同': 'That\'s the MAC address already in use',
    '保存中...': 'Saving...',
    '聚合口': 'Aggregated port',
    '全LAN口': 'All LAN ports',
    '确认是否关闭LAN口聚合功能': 'Turn off LAN port aggregation?',
    '请选择网口': 'Choose a port',
    '修改WAN口选择': 'Change WAN port',
    '设置成功，正在重启，请等待…': 'Saved, rebooting, please wait…',
    '未检测到宽带网线接入，请将网线连接到任意高亮网口': 'No internet cable found; plug it into any highlighted port',
    '智能识别网口“{$port}”作为WAN口': 'Port "{$port}" detected as the WAN port',
    '请将网线连接到任意高亮网口': 'Plug the cable into any highlighted port',
    '关闭IPv6设置成功': 'IPv6 turned off',
    '关闭IPv6设置失败': 'Couldn\'t turn off IPv6',
    '静态IP地址不合法': 'Invalid static IP address',
    '默认网关不合法': 'Invalid default gateway',
    'DNS服务器无法服务，可以尝试自定义DNS解决（114.114.114.114, 114.114.115.115 国外8.8.8.8 8.8.4.4)':
      'The DNS server isn\'t answering; try custom DNS (e.g. 8.8.8.8, 8.8.4.4)',
    '开启IPv6后，MTU取值范围为[1280-1492]，如需打开IPv6，请在上网设置中修改MTU值':
      'With IPv6 on, MTU must be 1280-1492; change the MTU in Internet settings to turn IPv6 on',
    '设置失败': 'Couldn\'t save',
    '，已断开': ', disconnected',
    '未能扫描到Wi-Fi,请确保射频开启': 'No Wi-Fi found; make sure the radio is on',
    '切换为无线中继模式后，您的访客wifi将被关闭': 'Guest Wi-Fi turns off in wireless repeater mode',
    '切换为有线中继模式后，您的访客wifi将被关闭': 'Guest Wi-Fi turns off in wired repeater mode',
    '选择已有网络': 'Choose an existing network',
    '尝试有线中继失败了': 'Wired repeater setup failed',
    '尝试无线中继失败了': 'Wireless repeater setup failed',
    '尝试工作模式切换失败了': 'Switching the operating mode failed',
    '修改上网设置': 'Change internet settings',
    '设置成功正在重启，需要30秒请等待...': 'Saved, rebooting. Takes 30 seconds, please wait...',

    // ---- Security page
    '无线访问控制': 'Wi-Fi access control',
    '控制模式：': 'Mode: ',
    '黑名单模式（不允许列表中设备访问）': 'Block list (listed devices can\'t connect)',
    '白名单模式（只允许列表中设备访问）': 'Allow list (only listed devices can connect)',
    '正在检测模式列表...': 'Loading the list...',
    '设备名称': 'Device name',
    '操作': 'Action',
    '正在查询中...': 'Loading...',
    '从在线列表添加': 'Add from connected devices',
    '手工添加': 'Add by hand',
    '保存并生效': 'Save and apply',
    '修改管理密码': 'Change admin password',
    '原密码': 'Current password',
    '新密码': 'New password',
    '确认密码': 'Confirm password',
    '管理后台访问控制': 'Admin page access control',
    '开启白名单功能后，将只允许名单中的设备访问管理后台，每次开启会将本机自动添加至白名单。':
      'With the allow list on, only listed devices can open the admin page. Turning it on always adds this computer.',
    'MAC地址白名单': 'MAC address allow list',
    '通过MAC地址添加设备': 'Add a device by MAC address',
    '设备信息': 'Device info',
    '连接时长': 'Connected for',
    '删除': 'Delete',
    '还没有设备添加进来': 'No devices added yet',
    '无可添加设备': 'No devices to add',
    '还没有设备连接进来': 'No devices connected yet',
    '黑名单设备列表': 'Blocked devices',
    '白名单设备列表': 'Allowed devices',
    '无线MAC地址过滤': 'Wi-Fi MAC address filter',
    '您没有在列表中添加任何设备，保存后所有设备将无法访问网络！请返回修改':
      'The list is empty: after saving, no device can use the network! Go back and fix it.',
    '您没有将当前设备添加至白名单，保存后本机将无法访问网络！': 'This computer isn\'t on the allow list: after saving it loses network access!',
    '您将当前设备添加至黑名单，保存后本机将无法访问网络！': 'This computer is on the block list: after saving it loses network access!',
    '添加失败，Mesh路由不能添加到黑名单': 'Can\'t add: Mesh routers can\'t be blocked',
    '请至少选择一个设备': 'Choose at least one device',
    '新密码与原密码相同': 'The new password is the same as the current one',
    '开启后访问协议将自动重定向为https，需要重新登录Web管理后台。确认开启？':
      'The admin page will switch to https and you\'ll need to log in again. Turn it on?',

    // ---- LAN page
    'DHCP服务': 'DHCP server',
    '什么是DHCP？': 'What is DHCP?',
    '1、DHCP 服务器：开启后，小米路由可以自动向您的接入设备分配 IP 地址、DNS 服务器地址等网络参数，并通过此功能实现 IP 地址的集中管理；关闭后，小米路由将不为您的计算机自动分配 IP 地址、DNS 服务器地址等网络参数，当另一台路由器通过 Wi-Fi 中继方式连接此路由器时，中继连接将会失败。':
      '1. DHCP server: when on, the router hands out IP addresses, DNS servers and other settings to your devices and manages addresses centrally. When off, devices get no automatic addresses, and another router can\'t connect to this one as a Wi-Fi repeater.',
    '2、租期：IP 地址分配给局域网计算机以后，如果使用时间超过这个租期，小米路由将给计算机分配新的 IP 地址。':
      '2. Lease: once a device has used its IP address longer than this, the router gives it a new one.',
    '3、路由器局域网IP地址：登陆Web配置后台的地址。': '3. Router LAN IP: the address of this admin page.',
    '4、默认网关：路由器下接入设备的默认网关，默认是路由器内网IP。':
      '4. Default gateway: the gateway given to devices; by default the router\'s own LAN IP.',
    '5、静态 IP 地址绑定：通常您计算机的 IP 地址由路由器动态分配。如果您希望计算机拥有静态 IP 地址，您可以在静态 IP 地址绑定列表中手动添加您计算机的 MAC 地址和希望使用的静态 IP 地址。注意，静态 IP 地址需与路由器的局域网 IP 地址在同一网段。':
      '5. Static IP binding: devices normally get changing addresses. To give a device a fixed one, add its MAC address and the IP you want to the static list. The IP must be in the same range as the router\'s LAN IP.',
    '开始IP': 'Start IP',
    '结束IP': 'End IP',
    '终端数量': 'Devices',
    '租约(分)': 'Lease (min)',
    '默认网关': 'Default gateway',
    '如何扩展': 'How to allow ',
    '台终端接入？': ' devices?',
    '局域网IP地址': 'LAN IP address',
    '1、局域网IP地址管理栏中，选择255.255.0.0掩码段。': '1. In the LAN IP settings, choose the 255.255.0.0 mask.',
    '2、保存子网掩码配置，系统将自动重启并开启': '2. Save the subnet mask; the router reboots and allows ',
    '台终端接入支持。': ' devices.',
    '注：此时路由器管理网段将变为10.31前缀，已保存的DHCP静态绑定、端口转发、DMZ主机设置、QoS限速等需要重新配置。':
      'Note: the router\'s addresses then start with 10.31, and saved static DHCP bindings, port forwarding, DMZ and QoS limits must be set up again.',
    '局域网IP': 'LAN IP',
    'DHCP静态IP分配': 'Static DHCP addresses',
    '已绑定的设备列表：': 'Bound devices:',
    '查询中...': 'Loading...',
    '解绑选中': 'Unbind selected',
    '解除绑定': 'Unbind',
    '没有设置信息': 'Nothing set up',
    '增加一项': 'Add an entry',
    '此操作需要重启才能生效': 'This takes effect after a reboot',
    '如果您已配置了以下内容，掩码的更改将会导致以下内容需重新配置：': 'Changing the mask means redoing these, if you set them up:',
    '-局域网默认网关': '- LAN default gateway',
    '-DHCP静态IP分配': '- Static DHCP addresses',
    '-端口转发': '- Port forwarding',
    '-DMZ主机设置': '- DMZ host',
    '是否提交?': 'Save?',
    '结束': 'End',
    '最大终端数量': 'Max devices',
    '租约': 'Lease',
    '绑定设备': 'Bind device',
    '你确定要解除此项绑定？': 'Remove this binding?',
    '存在IP冲突，请检查输入项': 'IP conflict, check your entries',
    '判断是否超出DHCP服务所设定的IP段': 'Checking against the DHCP range',
    '该IP不在可用IP范围内，请重新输入。您可以参考DHCP服务可用IP段来设定。':
      'That IP is outside the usable range; enter one within the DHCP range.',
    '出现异常，请刷新页面': 'Something went wrong, reload the page',
    '确定要删除这项数据吗': 'Delete this entry?',
    '你还未选择任何设备': 'No device selected',
    '确认要解除选中项目的绑定关系？': 'Unbind the selected entries?',
    '设置有误，请重新输入': 'Invalid setting, enter it again',
    '结束IP须大于开始IP，请重新设置': 'The end IP must be after the start IP',
    '最多接入设备为1000台，请重新设置': 'At most 1000 devices',
    '该过程中网络将会重启，造成设备短暂掉线，请问是否提交？': 'The network restarts and devices drop briefly. Save?',
    '配置为C类IP地址时，请使用掩码255.255.255.0': 'For a class C address use the mask 255.255.255.0',
    '此操作需要重启才能生效，是否提交?': 'This takes effect after a reboot. Save?',

    // ---- System page
    '如何自定义及定时控制路由器灯效': 'Customize the lights',
    '灯效控制': 'Lights',
    '此页面仅支持对路由器灯效进行简单管理，如需自定义或定时控制灯效请使用米家App绑定此路由器后进行管理':
      'This page only turns the lights on or off. To customize or schedule them, add the router in the Mi Home app.',
    '状态指示灯': 'Status light',
    '开启及关闭此路由器的网络/系统状态指示灯': 'Turn the network/system status light on or off',
    '网口灯': 'Port lights',
    '开启及关闭此路由器的网口灯': 'Turn the port lights on or off',
    '该操作会关闭路由器所有指示灯及氛围灯，请确认': 'This turns off all the router\'s lights. Continue?',
    '升级检测': 'Check for updates',
    '立即升级': 'Update now',
    '手动升级': 'Manual update',
    '更新日志': 'Changelog',
    '上传日志': 'Upload logs',
    '立即恢复': 'Restore now',
    '备份与恢复': 'Backup and restore',
    '备份路由器的配置，重新刷机或重置路由器后可以用来恢复。': 'Back up the router\'s settings to restore them after a reflash or reset.',
    '新建备份': 'New backup',
    '插件安装': 'Plugins',
    '手动安装': 'Manual install',
    '时区设置': 'Time zone',
    '当前系统时间：': 'Current time: ',
    '更改时区': 'Change time zone',
    '更改时间': 'Change time',
    '碰碰连': 'NFC Connect',
    '当前Wi-Fi的加密方式为超强加密（WPA3），在该模式下部分型号手机可能存在兼容性问题':
      'Wi-Fi uses WPA3 encryption; some phones may have trouble with NFC Connect in this mode',
    '该功能可为支持NFC的设备提供一碰入网服务。当前仅支持安卓手机，在使用前请确认：':
      'Lets NFC devices join Wi-Fi with a tap. Android phones only. Before using it, make sure:',
    '1. NFC功能开启': '1. NFC is on',
    '2. 屏幕处于亮屏解锁的状态': '2. The screen is on and unlocked',
    '路由器正常工作情况下建议使用系统升级检测进行升级。当系统无法升级时使用手动上传ROM包进行升级。':
      'Normally use Check for updates. Upload a ROM file by hand only when that doesn\'t work.',
    '请选择固件:': 'Choose firmware:',
    '开始升级': 'Start update',
    '当安装失败或需要降级到前一版本时使用手动安装插件。': 'Install a plugin by hand when installing fails or to go back to an older version.',
    '请选择插件安装包:': 'Choose the plugin package:',
    '开始安装': 'Start install',
    '可选备份': 'What to back up',
    '上网设置(拨号方式和宽带账号密码)': 'Internet settings (connection type and broadband account)',
    'DHCP服务和局域网IP设置': 'DHCP and LAN IP settings',
    '路由器名称和路由器管理密码': 'Router name and admin password',
    '开始备份': 'Start backup',
    '由于': 'Because of ',
    '原因，路由器设置备份失败！': ', the backup failed!',
    '请选择备份文件': 'Choose the backup file',
    '开始恢复': 'Start restore',
    '可选恢复的项目': 'What to restore',
    '路由器设置恢复成功，重启路由器即可生效！': 'Settings restored; reboot the router to apply them!',
    '恢复出厂设置操作会抹掉当前路由器的所有设置，建议您先进行配置备份再恢复出厂设置。':
      'A factory reset erases all router settings. Make a backup first.',
    '直接恢复出厂设置': 'Factory reset now',
    '1.恢复出厂设置操作会抹掉当前路由器的所有设置；': '1. A factory reset erases all router settings;',
    '2.若此前已完成Mesh组网，子路由将会失去连接，待恢复出厂设置后需重新进行组网。':
      '2. Mesh nodes lose their connection and must be added again after the reset.',
    '年': 'Year',
    '月': 'Month',
    '日': 'Day',
    '时': 'Hour',
    '当前时间': 'Current time',
    '请注意：升级将会使所有已连接设备的网络中断，升级过程中请勿断开路由器电源或关闭本页面！':
      'Note: updating cuts every device\'s connection. Don\'t unplug the router or close this page during the update!',
    '当前版本{$ver}，{$ret}': 'Current version {$ver}, {$ret}',
    '发现新版本,升级包大小为{$size}，请立即升级。': 'New version found ({$size}), update now.',
    '发现新版本,升级包大小为': 'New version found, size ',
    '，请立即升级。': '. Update now.',
    '正在检测更新，请稍候...': 'Checking for updates, please wait...',
    '你的版本是最新的，无需升级。': 'You have the latest version.',
    '检查失败，网络繁忙请刷新页面重试。': 'Check failed, network busy; reload and try again.',
    '升级失败，系统错误或路由硬盘已满。': 'Update failed: system error or the router\'s storage is full.',
    '你未选择文件，请重新选择': 'No file chosen',
    '文件格式错误，请重新选择': 'Wrong file format, choose another',
    '日志上传成功': 'Logs uploaded',
    '碰碰连设置失败': 'Couldn\'t set up NFC Connect',
    '插件安装成功': 'Plugin installed',
    '安装失败，系统错误或路由器空间不足。': 'Install failed: system error or not enough space.',
    '手动安装插件': 'Install plugin by hand',
    '备份路由器设置': 'Back up router settings',
    '至少选择1个': 'Choose at least one',
    '从备份恢复路由器设置': 'Restore settings from backup',
    '系统错误，请重试。': 'System error, try again.',
    '{$y}年{$mo}月{$d}日 {$h}:{$mi}:{$s}': '{$y}-{$mo}-{$d} {$h}:{$mi}:{$s}',
    '设置成功，稍后生效，请等待一会刷新。': 'Saved; it applies shortly, reload in a moment.',

    // ---- Advanced submenu
    'QoS智能限速': 'QoS speed limits',
    '端口转发': 'Port forwarding',
    '网口自定义': 'Port settings',

    // ---- QoS page
    '最高速度设置': 'Max speed',
    '最高上传速度': 'Max upload speed',
    '最高下载速度': 'Max download speed',
    '限速设置': 'Speed limits',
    '无限速阈值，请先进行限速设置': 'No limit set; set the speed limits first',
    '当外网下载带宽超过50Mbps时，建议无需开启QoS功能': 'With more than 50 Mbps download, QoS usually isn\'t needed',
    'QoS智能分配': 'QoS smart allocation',
    '当前QoS服务暂未开启': 'QoS is off',
    '根据应用优先级分配网速': 'Share bandwidth by app priority',
    '自动模式': 'Auto',
    '优先级模式': 'Priority',
    '手工限速模式': 'Manual limits',
    '游戏优先': 'Games first',
    '网页优先': 'Web first',
    '视频优先': 'Video first',
    '自动模式下路由器会根据当前网络使用情况动态调整带宽分配，保证网络体验流畅':
      'Auto: the router shares bandwidth based on current use to keep things smooth',
    '优先级模式下路由器会动态调整带宽分配，保证优先级较高的设备网络体验流畅':
      'Priority: the router shares bandwidth so higher-priority devices stay smooth',
    '手工模式下路由器会根据您设置的速度调整带宽分配': 'Manual: the router uses the speeds you set',
    '系统根据设备需要自动调配网速': 'Bandwidth is shared automatically as devices need it',
    '优先保证打游戏的网速，不卡顿不掉线': 'Games get bandwidth first: no lag, no drops',
    '优先保证浏览网页的网速，大图秒打开': 'Web browsing gets bandwidth first: pages load fast',
    '优先保证看视频的网速，高清也流畅': 'Video gets bandwidth first: smooth even in HD',
    '家庭WiFi限速': 'Home Wi-Fi limits',
    '当前网速': 'Current speed',
    '限速模式': 'Limit mode',
    '最大速度': 'Max speed',
    '编辑': 'Edit',
    '优先级': 'Priority',
    '访客WiFi限速:': 'Guest Wi-Fi limit: ',
    '访客WiFi限速': 'Guest Wi-Fi limit',
    '上传限速': 'Upload limit',
    '下载限速': 'Download limit',
    '路由器自身上传下载限速:': 'Router\'s own upload/download limit: ',
    '路由器自身上传下载限速': 'Router\'s own upload/download limit',
    '正在测速...': 'Testing speed...',
    '还没有进行测速': 'No speed test yet',
    '立即测速': 'Test speed now',
    '发生未知错误，测速失败': 'Unknown error, speed test failed',
    '重新测速': 'Test again',
    '测速不准？': 'Result wrong?',
    '系统自动': 'Automatic',
    '上传速度': 'Upload speed',
    '下载速度': 'Download speed',
    'IP和MAC': 'IP and MAC',
    '低': 'Low',
    '中': 'Medium',
    '高': 'High',
    '暂无设备接入': 'No devices connected',
    '上次测速': 'Last test',
    '外网速度': 'Internet speed',
    '开始测速': 'Start test',
    '设置带宽': 'Set bandwidth',
    '网络速度': 'Network speed',
    '正在测速，请等待。': 'Testing speed, please wait.',
    '外网带宽检测': 'Internet speed test',
    '无限制': 'Unlimited',
    '系统错误，请重试': 'System error, try again',
    '未设置': 'Not set',
    '你确定要清除这个设备的QoS配置？': 'Clear this device\'s QoS settings?',
    '设置QoS': 'Set QoS',

    // ---- DDNS page
    '什么是DDNS？': 'What is DDNS?',
    'DDNS（Dynamic Domain Name Server）是动态域名服务的缩写。': 'DDNS stands for Dynamic Domain Name Server.',
    '目前路由器拨号上网获得的多半都是动态IP，DDNS可以将路由器变化的外网IP和固定的域名绑定，从而用户可以在外网通过该固定域名来访问路由器。':
      'Most connections give the router a changing public IP. DDNS ties it to a fixed domain name, so you can reach the router from the internet by that name.',
    '如何设置DDNS？': 'How to set up DDNS?',
    '1. 通过DDNS服务商获得域名及账号密码信息；': '1. Get a domain name and account from a DDNS provider;',
    '2. 开启DDNS服务，添加服务，输入前一步获取的信息，保存并启用该服务。':
      '2. Turn on DDNS, add a service with that information, save and enable it.',
    '注意事项:': 'Notes:',
    '可以通过内置的DDNS运营商去该运营商官网去注册账号及申请域名；': 'You can register an account and domain on a listed provider\'s website;',
    '用户名和密码为注册该运营商的用户名与密码；': 'User name and password are your account at that provider;',
    '主机名称为从运营商申请的域名；': 'Host name is the domain you got from the provider;',
    '强制检查为WAN口IP的检查时间，如无特殊需求，建议使用默认配置；': 'Status check is how often the WAN IP is checked; keep the default unless needed;',
    '强制更新为域名与IP强制更新的时间，如无特殊需求，建议使用默认配置；': 'Forced update is how often the domain is re-sent; keep the default unless needed;',
    '只能同时开启一个DDNS服务。': 'Only one DDNS service can be on at a time.',
    '服务列表：': 'Services:',
    '服务提供商及主机名称': 'Provider and host name',
    '最近更新': 'Last update',
    '状态': 'Status',
    '添加服务': 'Add service',
    '手动更新': 'Update now',
    '停用': 'Disable',
    '启用': 'Enable',
    '连接正常': 'Connected',
    '连接中...': 'Connecting...',
    '连接错误': 'Connection error',
    '服务提供商': 'Provider',
    '花生壳（oray.com）': 'Oray (oray.com)',
    '公云（3322.org）': 'PubYun (3322.org)',
    '用户名': 'User name',
    '主机名称': 'Host name',
    '状态检查': 'Status check',
    '强制更新': 'Forced update',
    '还没有服务添加进来': 'No services added yet',
    '状态检查的分钟间隔': 'Status check interval (minutes)',
    '强制更新的小时间隔': 'Forced update interval (hours)',
    '更新成功': 'Updated',
    '未启动无法强制更新': 'Not running, can\'t force an update',
    '编辑服务': 'Edit service',
    '暂无更新': 'No updates yet',

    // ---- Port forwarding page
    '端口转发规则列表：': 'Port forwarding rules:',
    '协议': 'Protocol',
    '外部端口': 'External port',
    '内部IP地址': 'Internal IP',
    '内部端口': 'Internal port',
    '范围转发规则列表：': 'Port range rules:',
    '起始端口': 'Start port',
    '结束端口': 'End port',
    '目标IP': 'Target IP',
    '开启DMZ功能可以将内网某一个设备的IP映射到外网，方便从外网访问到该设备。':
      'DMZ exposes one device on your network to the internet so it can be reached from outside.',
    'DMZ状态：': 'DMZ status: ',
    '未生效': 'Not active',
    'UPnP状态': 'UPnP status',
    'UPnP设备列表：': 'UPnP devices:',
    '应用名称': 'App name',
    '客户端IP': 'Client IP',
    '2.4G 漫游': '2.4 GHz roaming',
    '5G 漫游': '5 GHz roaming',
    '拒绝阈值': 'Reject threshold',
    '踢除阈值': 'Kick threshold',
    'dBm(取值范围-95~-65)': 'dBm (-95 to -65)',
    'dBm(取值范围-100~-70)': 'dBm (-100 to -70)',
    'dBm(取值范围-85~-55)': 'dBm (-85 to -55)',
    'dBm(取值范围-90~-60)': 'dBm (-90 to -60)',
    'TCP和UDP': 'TCP and UDP',
    '内部IP地址：': 'Internal IP: ',
    '目标IP：': 'Target IP: ',
    '添加规则': 'Add rule',
    'IP地址最后一位': 'last number of the IP',
    '需在-95~-65范围内取值': 'Must be from -95 to -65',
    '需在-100~-70范围内取值': 'Must be from -100 to -70',
    '需在-85~-55范围内取值': 'Must be from -85 to -55',
    '需在-90~-60范围内取值': 'Must be from -90 to -60',
    '没有UPnP设备': 'No UPnP devices',
    'UPnP未开启': 'UPnP is off',
    '新建端口转发规则': 'New port forwarding rule',
    '确定要删除这条规则吗？': 'Delete this rule?',
    '新建范围转发规则': 'New port range rule',
    '编辑端口转发规则': 'Edit port forwarding rule',
    '更新': 'Update',
    '编辑范围转发规则': 'Edit port range rule',
    '已生效': 'Active',
    '端口转发开启了，不可以设置DMZ': 'Port forwarding is on, so DMZ can\'t be set',
    '设置DMZ': 'Set DMZ',
    '关闭成功，生效中，请稍候...': 'Turned off, applying, please wait...',
    '配置中，请稍候...': 'Configuring, please wait...',

    // ---- VPN page
    '什么是VPN': 'What is a VPN',
    'VPN属于远程访问技术，应用举例：出差员工在外地通过VPN服务访问企业内部网络。':
      'A VPN gives remote access to a network, e.g. an employee on a trip reaching the company network.',
    'PPTP（Point to Point Tunneling Protocol）和L2TP（Layer 2 Tunneling Protocol）为两种互联网隧道协议，都属于VPN（Virtual Private Network）虚拟专用网络的不同协议分类方式。':
      'PPTP (Point to Point Tunneling Protocol) and L2TP (Layer 2 Tunneling Protocol) are two tunneling protocols used for VPNs (Virtual Private Networks).',
    '如何设置VPN': 'How to set up a VPN',
    '1.首先需要在VPN服务商官网上注册账号，获得用户名、密码、服务器地址、协议类型等信息。':
      '1. Register with a VPN provider to get a user name, password, server address and protocol type.',
    '2.将信息添加到服务中，并启用该VPN服务': '2. Add them as a service and enable it',
    '1.VPN用户名、密码、服务器地址、协议类型等信息需要向VPN服务商获取。':
      '1. The VPN user name, password, server address and protocol come from your VPN provider.',
    '2.服务器地址可以是域名或IP地址，具体由服务商提供。': '2. The server address can be a domain or IP, as given by the provider.',
    '3.开启VPN功能后，游戏网口的优先转发特性将无法生效。': '3. With the VPN on, the gaming port\'s priority forwarding doesn\'t work.',
    'VPN 服务列表:': 'VPN services:',
    '协议类型': 'Protocol type',
    '服务器地址': 'Server address',
    '开机自动连接': 'Connect at startup',
    '智能VPN分流': 'Smart VPN split',
    '你可以自定义哪些服务或设备会走VPN的流量': 'Choose which services or devices go through the VPN',
    '按服务地址分流': 'Split by service address',
    '按设备分流': 'Split by device',
    '可以通过添加服务地址来限定哪些服务流量会经过VPN': 'Only traffic to the addresses you add goes through the VPN',
    '可以通过添加设备来限定哪些设备可以使用VPN流量': 'Only the devices you add use the VPN',
    '添加服务地址': 'Add service address',
    '从设备列表添加设备': 'Add from device list',
    '通过MAC地址添加': 'Add by MAC address',
    '小米服务走VPN': 'Xiaomi services through VPN',
    '当你需要通过VPN使用外网时，可以开启此功能保证小米路由器APP远程服务可用，其他情况下关闭此功能':
      'Turn this on when you reach the internet through the VPN, so the Xiaomi router app\'s remote access keeps working; otherwise keep it off',
    '服务器': 'Server',
    '断开连接': 'Disconnect',
    '取消连接': 'Cancel connecting',
    '连接': 'Connect',
    '重连': 'Reconnect',
    '请输入设备的MAC地址': 'Enter the device\'s MAC address',
    '请输入地址': 'Enter an address',
    '地址': 'Address',
    '连接失败': 'Connection failed',
    '还未添加服务地址': 'No service addresses yet',
    '还未添加设备': 'No devices yet',
    '已连接': 'Connected',
    '未启用': 'Not enabled',
    '连接异常': 'Connection problem',
    '正在断开...': 'Disconnecting...',
    '你确定要删除此项吗？': 'Delete this item?',
    '重新连接vpn后该设置将生效，是否确认重新连接？': 'This applies after the VPN reconnects. Reconnect now?',
    '在线': 'Online',
    '离线': 'Offline',
    '开启该功能后，需要您重新连接VPN方可生效，且智能分流功能将关闭。若开启后发现路由器App远程访问出现异常，请您关闭。是否确认开启？':
      'This applies after the VPN reconnects and turns off smart split. If the router app\'s remote access breaks, turn it off. Turn it on?',
    '请选择需要使用VPN的设备': 'Choose the devices that use the VPN',
    '通过MAC地址添加要使用VPN的设备': 'Add a VPN device by MAC address',
    '添加要使用VPN的服务地址': 'Add an address to reach through the VPN',
    '当前正在连接的VPN将被断开，重新连接后该设置将生效。': 'The current VPN connection will drop; the setting applies after reconnecting.',

    // ---- Port settings page (dual WAN, IPTV, aggregation, gaming port)
    '双WAN功能介绍': 'About dual WAN',
    '双WAN设置': 'Dual WAN',
    '什么是双WAN？': 'What is dual WAN?',
    '双WAN功能是指支持两条外网宽带线路同时工作以带来更佳的网络体验，其主要的功能如下：':
      'Dual WAN uses two internet lines at once for a better connection. It offers:',
    '（1）增加带宽（带宽聚合模式）：可同时使用两条外网宽带线路以增加外网总带宽，实现更大的下载速率':
      '(1) More bandwidth (aggregation mode): both lines are used together for faster downloads',
    '（2）冗余备份（WAN1优先，WAN2备份/WAN2优先，WAN1备份）：如果其中一条外网宽带出现故障，可以数据分流到另一条宽带上，以保障与外部网络连通':
      '(2) Backup (WAN1 first, WAN2 backup / WAN2 first, WAN1 backup): if one line fails, traffic moves to the other',
    '（3）外网路径选择（带宽聚合模式）：可选择部分设备的数据优先通过固定的WAN口宽带，比如部分数据走移动网络，部分数据走电信网络':
      '(3) Route choice (aggregation mode): send some devices\' traffic through a chosen line, e.g. some via one provider and some via another',
    '1.开启双WAN功能后会与部分功能冲突，若仍想使用冲突功能，请先尝试关闭双WAN后再试':
      '1. Dual WAN conflicts with some features; turn dual WAN off to use them',
    '2.若某些终端设备出现金融类app无法正常使用的情况，可尝试在“WAN口策略”功能中将该设备设置为“WAN1优先”或“WAN2优先”后再试':
      '2. If banking apps misbehave on a device, set that device to "WAN1 first" or "WAN2 first" under WAN policy',
    '3.请勿将WAN1或WAN2口与其他Mesh组网设备相连': '3. Don\'t connect WAN1 or WAN2 to other Mesh devices',
    '4.双WAN功能仅支持IPv4，IPV6及IPTV功能仅支持在WAN1上部署': '4. Dual WAN is IPv4 only; IPv6 and IPTV work only on WAN1',
    '请选择网口作为WAN口，并在': 'Choose a port as WAN, then configure it in ',
    '中进行WAN口配置': '',
    '带宽聚合': 'Bandwidth aggregation',
    'WAN1优先，WAN2备份': 'WAN1 first, WAN2 backup',
    'WAN2优先，WAN1备份': 'WAN2 first, WAN1 backup',
    'WAN1口/WAN2口转发比例设置': 'WAN1/WAN2 traffic ratio',
    'WAN1口': 'WAN1',
    'WAN2口': 'WAN2',
    'WAN口转发规则设置': 'WAN routing rules',
    'WAN口转发规则列表：': 'WAN routing rules:',
    'WAN口策略': 'WAN policy',
    '设备IP': 'Device IP',
    'WAN1口带宽': 'WAN1 bandwidth',
    'WAN2口带宽': 'WAN2 bandwidth',
    'WAN1优先': 'WAN1 first',
    'WAN2优先': 'WAN2 first',
    '网络服务提供商配置': 'Provider profile',
    '自定义': 'Custom',
    '桥接模式': 'Bridge mode',
    'IPTV VLAN优先级(0~7)': 'IPTV VLAN priority (0-7)',
    'IPTV VLAN优先级': 'IPTV VLAN priority',
    'LAN口聚合注意事项': 'LAN aggregation notes',
    '网口协商速率不同时，将无法聚合成功。对端网卡需开启LACP协议。':
      'Ports at different link speeds can\'t be combined. The device on the other end needs LACP turned on.',
    '游戏网口注意事项': 'Gaming port notes',
    '请注意，开启以下功能后游戏网口的优先转发功能将会失效：': 'The gaming port\'s priority forwarding stops working when these are on:',
    '1. Qos设置；': '1. QoS;',
    '2. VPN服务与智能VPN分流。': '2. VPN and smart VPN split.',
    '游戏网口传输的数据会被优先转发，使得延迟更低，更适用于游戏和语音场景':
      'Traffic on the gaming port is forwarded first for lower latency; good for games and voice chat',
    '为保证正常上网，请在“常用设置”-“上网设置”中进行WAN口配置': 'To stay online, configure the WAN port in Settings > Internet',
    '不再提示': 'Don\'t show again',
    '前往上网配置设置': 'Go to Internet settings',
    '前往上网设置配置': 'Go to Internet settings',
    '没有未添加的设备连接进来': 'No other devices connected',
    '配置生效过程中连接在路由器上的有线设备会短暂断开网络，且以下功能会无法使用：':
      'While this applies, wired devices drop briefly, and these stop working:',
    '1. 此路由已生效的VPN服务': '1. The active VPN',
    '2. QoS智能限速服务': '2. QoS speed limits',
    '3. 智能选择WAN口功能': '3. Automatic WAN port choice',
    '确认保存吗？': 'Save?',
    '确认是否关闭IPTV功能': 'Turn off IPTV?',
    '保存成功': 'Saved',
    '请选择一个网口作为IPTV口': 'Choose a port for IPTV',
    '配置生效过程中连接在路由器上的有线设备会短暂断开网络，请确认是否保存修改？':
      'Wired devices drop briefly while this applies. Save?',
    'LAN口聚合成功': 'LAN ports combined',
    '聚合失败，检测到聚合的LAN口未插入网线': 'Aggregation failed: a chosen LAN port has no cable',
    '聚合失败，检测到选定的LAN口实际生效速率不同': 'Aggregation failed: the chosen LAN ports run at different speeds',
    '聚合中，请确保接入聚合口的设备支持聚合功能': 'Combining; make sure the connected device supports aggregation',
    '聚合未开启，请配置聚合': 'Aggregation is off; set it up',
    '网口': 'Port',
    '未连接': 'Not connected',
    '速率为': 'speed ',
    '确认是否关闭游戏网口功能': 'Turn off the gaming port?',
    '错误：策略数量最大值为1000': 'Error: at most 1000 rules',
    '还没有策略加入': 'No rules yet',
    '网络异常，获取列表失败': 'Network error, couldn\'t load the list',
    '双WAN设置中，请稍等...': 'Applying dual WAN, please wait...',
    '确认是否关闭双WAN功能': 'Turn off dual WAN?',
    '设置中': 'Applying',
    '设置中，请稍等...': 'Applying, please wait...',
    '修改端口设置': 'Change port settings',

    // ---- Dialogs and common buttons
    '确定': 'OK',
    '确认': 'Confirm',
    '取消': 'Cancel',
    '保存': 'Save',
    '应用': 'Apply',
    '关闭': 'Close',
    '返回': 'Back',
    '提示': 'Notice',
    '提示信息': 'Notice',
    '确认信息': 'Confirm',
    '消息框': 'Message',
    '加载中...': 'Loading...',
    '处理中...': 'Working...',
    '设置成功': 'Saved',
    '设置成功！': 'Saved!',
    '可用端口不足，请先关闭其他端口功能后再试': 'No free port. Turn off another port function first.',
    '游戏网口': 'Gaming port',
    '请选择一个网口作为游戏网口': 'Choose a port to use as the gaming port',
    '小时': 'h',
    '分': 'min',
    '分钟': 'min',
    '秒': 's',
    '天': 'days',

    // ---- Form validation messages
    '请输入一个{$0}位以内正整数。': 'Enter a positive whole number of up to {$0} digits.',
    '数字输入格式为"{$0}"。': 'Number format: "{$0}".',
    '输入值太大，最大允许{$0}。': 'Too large, the maximum is {$0}.',
    '输入值太小，最小允许{$0}。': 'Too small, the minimum is {$0}.',
    '请输入一个2位负整数。': 'Enter a negative 2-digit whole number.',
    '您输入的范围不合理。': 'That range isn\'t valid.',
    '数字前面好像有多余的"0"。': 'The number seems to have an extra leading "0".',
    '请输入正确的端口号。': 'Enter a valid port number.',
    '日期输入格式为"YYYY-MM-DD"。': 'Date format: "YYYY-MM-DD".',
    '日期太晚，最晚允许{$0}。': 'Date too late, the latest allowed is {$0}.',
    '日期太早，最早允许{$0}。': 'Date too early, the earliest allowed is {$0}.',
    '起始日期不能大于截止日期。': 'The start date can\'t be after the end date.',
    '截止日期不能小于起始日期。': 'The end date can\'t be before the start date.',
    '时间跨度不得超过{$0}天。': 'The span can\'t exceed {$0} days.',
    '最多允许{$0}个字。': 'At most {$0} characters.',
    '{$1}字太多，最多允许{$0}字': '{$1}: too long, at most {$0} characters',
    '请至少输入{$0}个字。': 'Enter at least {$0} characters.',
    '{$1}字太少，最少允许{$0}字': '{$1}: too short, at least {$0} characters',
    '最多允许{$0}个字节。': 'At most {$0} bytes.',
    '{$1}字节太多，最多允许{$0}字节': '{$1}: too long, at most {$0} bytes',
    '请至少输入{$0}个字节。': 'Enter at least {$0} bytes.',
    '{$1}字节太少，最少允许{$0}字节': '{$1}: too short, at least {$0} bytes',
    '两次输入不一致。': 'The two entries don\'t match.',
    '请检查您输入的时间格式。': 'Check the time format.',
    '请检查您输入的Email格式。': 'Check the email address.',
    '请检查您输入的手机号码。': 'Check the mobile number.',
    '请检查您输入的电话号码。': 'Check the phone number.',
    '请检查您输入的电话区号。': 'Check the area code.',
    '请检查您输入的电话分机号码。': 'Check the extension number.',
    '无效的手机号': 'Invalid mobile number',
    '请输入0~10000的正整数。': 'Enter a whole number from 0 to 10000.',
    '请检查您输入的邮政编码。': 'Check the postal code.',
    '请检查您输入的身份证号码，目前只支持15位或者18位。': 'Check the ID number (15 or 18 digits).',
    '请检查您输入的银行账号。': 'Check the bank account number.',
    '请检查您输入的姓名。': 'Check the name.',
    '请检查您输入的验证码。': 'Check the verification code.',
    '请检查您选择的图片文件路径，只支持jpg、jpeg、png、gif、tif、bmp格式。':
      'Check the image file; only jpg, jpeg, png, gif, tif and bmp are supported.',
    '请检查您的输入。': 'Check your input.',
    '请填写{$0}。': 'Fill in {$0}.',
    '请选择{$0}。': 'Choose {$0}.',
    '请上传{$0}。': 'Upload {$0}.',
    '{$0}输入不完整.': '{$0} is incomplete.',
    '输入格式不正确,请输入标准字符': 'Invalid format, use standard characters',
    'MAC地址格式有误，如ab:cd:ef:11:22:33': 'Invalid MAC address, e.g. ab:cd:ef:11:22:33',
    '黑白名单名称不支持特殊字符$ & | ；‘ ·': 'Block/allow list names can\'t contain $ & | ; ‘ ·',
    '密码输入有误': 'Wrong password',
    '请输入数字、英文字母或英文符号': 'Use digits, Latin letters or ASCII symbols',
    '该地址由4个 0~255 之间的数字组成，数字之间用点区隔': 'The address is 4 numbers from 0 to 255 separated by dots',
    'IPv6地址由8组四个十六进制数组成，每组之间用:区隔': 'An IPv6 address is 8 groups of 4 hex digits separated by ":"',
    'LAN IPv6前缀需要以::结尾': 'The LAN IPv6 prefix must end with ::',
    '必须是完整的URL,如 http://miwifi.com': 'Must be a full URL, e.g. http://miwifi.com',
    '请输入正确的服务器地址': 'Enter a valid server address',

    // ---- Misc
    '你的浏览器禁止了Javascript功能，会造成无法使用系统进行路由器管理，请开启。':
      'JavaScript is disabled in your browser; enable it to manage the router.',

    // ---- Chinese punctuation left between translated pieces
    '：': ': ',
    '，': ', ',
    '。': '. ',
    '（': ' (',
    '）': ')',
    '；': '; ',
    '？': '?',
    '！': '!',
  };

  // Time zone list (System page). Two sets: the old and the new list.
  Object.assign(DICT, {
    '(UTC-12)国际日期变更线西': '(UTC-12) International Date Line West',
    '(UTC-11)萨摩亚群岛': '(UTC-11) Samoa',
    '(UTC-11)协调世界时': '(UTC-11) Coordinated Universal Time-11',
    '(UTC-10)夏威夷': '(UTC-10) Hawaii',
    '(UTC-9:30)马克萨斯群岛标准时间': '(UTC-9:30) Marquesas Islands',
    '(UTC-9)阿拉斯加': '(UTC-9) Alaska',
    '(UTC-8)太平洋时间(美国和加拿大)': '(UTC-8) Pacific Time (US & Canada)',
    '(UTC-8)下加利福尼亚州': '(UTC-8) Baja California',
    '(UTC-7)奇瓦瓦,拉巴斯,马萨特兰': '(UTC-7) Chihuahua, La Paz, Mazatlan',
    '(UTC-7)山地时间(美国和加拿大)': '(UTC-7) Mountain Time (US & Canada)',
    '(UTC-7)亚利桑那': '(UTC-7) Arizona',
    '(UTC-6)瓜达拉哈拉,墨西哥城,蒙特雷': '(UTC-6) Guadalajara, Mexico City, Monterrey',
    '(UTC-6)萨斯克彻温': '(UTC-6) Saskatchewan',
    '(UTC-6)中部时间(美国和加拿大)': '(UTC-6) Central Time (US & Canada)',
    '(UTC-6)中美洲': '(UTC-6) Central America',
    '(UTC-5)波哥大,利马,基多': '(UTC-5) Bogota, Lima, Quito',
    '(UTC-5)东部时间(美国和加拿大)': '(UTC-5) Eastern Time (US & Canada)',
    '(UTC-5)印第安纳州(东部)': '(UTC-5) Indiana (East)',
    '(UTC-4:30)加拉加斯': '(UTC-4:30) Caracas',
    '(UTC-4)大西洋时间(加拿大)': '(UTC-4) Atlantic Time (Canada)',
    '(UTC-4)库亚巴': '(UTC-4) Cuiaba',
    '(UTC-4)乔治敦,拉巴斯,马瑙斯,圣湖安': '(UTC-4) Georgetown, La Paz, Manaus, San Juan',
    '(UTC-4)圣地亚哥': '(UTC-4) Santiago',
    '(UTC-4)亚松森': '(UTC-4) Asuncion',
    '(UTC-3:30)纽芬兰': '(UTC-3:30) Newfoundland',
    '(UTC-3)巴西利亚': '(UTC-3) Brasilia',
    '(UTC-3)布宜诺斯艾利斯': '(UTC-3) Buenos Aires',
    '(UTC-3)格陵兰': '(UTC-3) Greenland',
    '(UTC-3)卡宴,福塔雷萨': '(UTC-3) Cayenne, Fortaleza',
    '(UTC-3)蒙得维的亚': '(UTC-3) Montevideo',
    '(UTC-2)协调世界时-02': '(UTC-2) Coordinated Universal Time-02',
    '(UTC-2)中大西洋': '(UTC-2) Mid-Atlantic',
    '(UTC-1)佛得角群岛': '(UTC-1) Cape Verde Is.',
    '(UTC-1)亚速尔群岛': '(UTC-1) Azores',
    '(UTC)都柏林,爱丁堡,里斯本,伦敦': '(UTC) Dublin, Edinburgh, Lisbon, London',
    '(UTC)卡萨布兰卡': '(UTC) Casablanca',
    '(UTC)蒙罗维亚,雷克雅未克': '(UTC) Monrovia, Reykjavik',
    '(UTC)协调世界时': '(UTC) Coordinated Universal Time',
    '(UTC+1)阿姆斯特丹,柏林,伯尔尼,罗马,斯德歌尔摩,维也纳': '(UTC+1) Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna',
    '(UTC+1)贝尔格莱德,布拉迪斯拉发,布达佩斯,卢布尔雅那': '(UTC+1) Belgrade, Bratislava, Budapest, Ljubljana',
    '(UTC+1)布鲁塞尔,哥本哈根,马德里,巴黎': '(UTC+1) Brussels, Copenhagen, Madrid, Paris',
    '(UTC+1)萨拉热窝,斯科普里,华沙,萨格勒布': '(UTC+1) Sarajevo, Skopje, Warsaw, Zagreb',
    '(UTC+1)温得和克': '(UTC+1) Windhoek',
    '(UTC+1)中非西部': '(UTC+1) West Central Africa',
    '(UTC+2)安曼': '(UTC+2) Amman',
    '(UTC+2)贝鲁特': '(UTC+2) Beirut',
    '(UTC+2)大马士革': '(UTC+2) Damascus',
    '(UTC+2)哈拉雷,比勒陀利亚': '(UTC+2) Harare, Pretoria',
    '(UTC+2)赫尔辛基,基辅,里加,索非亚,塔林,维尔纽斯': '(UTC+2) Helsinki, Kyiv, Riga, Sofia, Tallinn, Vilnius',
    '(UTC+2)开罗': '(UTC+2) Cairo',
    '(UTC+2)明斯克': '(UTC+2) Minsk',
    '(UTC+2)雅典,布加勒斯特': '(UTC+2) Athens, Bucharest',
    '(UTC+2)耶路撒冷': '(UTC+2) Jerusalem',
    '(UTC+2)伊斯坦布尔': '(UTC+2) Istanbul',
    '(UTC+3)巴格达': '(UTC+3) Baghdad',
    '(UTC+3)加里宁格勒': '(UTC+3) Kaliningrad',
    '(UTC+3)科威特,利雅得': '(UTC+3) Kuwait, Riyadh',
    '(UTC+3)内罗毕': '(UTC+3) Nairobi',
    '(UTC+3:30)德黑兰': '(UTC+3:30) Tehran',
    '(UTC+4)阿布扎比,马斯喀特': '(UTC+4) Abu Dhabi, Muscat',
    '(UTC+4)埃里温': '(UTC+4) Yerevan',
    '(UTC+4)巴库': '(UTC+4) Baku',
    '(UTC+4)第比利斯': '(UTC+4) Tbilisi',
    '(UTC+4)路易港': '(UTC+4) Port Louis',
    '(UTC+4)莫斯科,圣彼得堡,伏尔加格勒': '(UTC+4) Moscow, St. Petersburg, Volgograd',
    '(UTC+4:30)喀布尔': '(UTC+4:30) Kabul',
    '(UTC+5)塔什干': '(UTC+5) Tashkent',
    '(UTC+5)伊斯兰堡,卡拉奇': '(UTC+5) Islamabad, Karachi',
    '(UTC+5:30)钦奈,加尔各答,孟买,新德里': '(UTC+5:30) Chennai, Kolkata, Mumbai, New Delhi',
    '(UTC+5:30)斯里加亚渥登普拉': '(UTC+5:30) Sri Jayawardenepura',
    '(UTC+5:45)加德满都': '(UTC+5:45) Kathmandu',
    '(UTC+6)阿斯塔纳': '(UTC+6) Astana',
    '(UTC+6)达卡': '(UTC+6) Dhaka',
    '(UTC+6)叶卡捷琳堡': '(UTC+6) Yekaterinburg',
    '(UTC+6:30)仰光': '(UTC+6:30) Yangon',
    '(UTC+7)曼谷,河内,雅加达': '(UTC+7) Bangkok, Hanoi, Jakarta',
    '(UTC+7)新西伯利亚': '(UTC+7) Novosibirsk',
    '(UTC+8)北京,重庆,香港特别行政区,乌鲁木齐': '(UTC+8) Beijing, Chongqing, Hong Kong, Urumqi',
    '(UTC+8)吉隆坡,新加坡': '(UTC+8) Kuala Lumpur, Singapore',
    '(UTC+8)克拉斯诺亚尔斯克': '(UTC+8) Krasnoyarsk',
    '(UTC+8)珀斯': '(UTC+8) Perth',
    '(UTC+8)台北': '(UTC+8) Taipei',
    '(UTC+8)乌兰巴托': '(UTC+8) Ulaanbaatar',
    '(UTC+8:30)朝鲜标准时间': '(UTC+8:30) North Korea',
    '(UTC+9)大阪,札幌,东京': '(UTC+9) Osaka, Sapporo, Tokyo',
    '(UTC+9)首尔': '(UTC+9) Seoul',
    '(UTC+9)伊尔库茨克': '(UTC+9) Irkutsk',
    '(UTC+9:30)阿德莱德': '(UTC+9:30) Adelaide',
    '(UTC+9:30)达尔文': '(UTC+9:30) Darwin',
    '(UTC+10)布里斯班': '(UTC+10) Brisbane',
    '(UTC+10)关岛,莫尔兹比港': '(UTC+10) Guam, Port Moresby',
    '(UTC+10)霍巴特': '(UTC+10) Hobart',
    '(UTC+10)堪培拉,墨尔本,悉尼': '(UTC+10) Canberra, Melbourne, Sydney',
    '(UTC+10)雅库茨克': '(UTC+10) Yakutsk',
    '(UTC+10:30)澳大利亚远东标准时间': '(UTC+10:30) Lord Howe Island',
    '(UTC+11)符拉迪沃斯托克': '(UTC+11) Vladivostok',
    '(UTC+11)所罗门群岛,新喀里多尼亚': '(UTC+11) Solomon Is., New Caledonia',
    '(UTC+11:30)诺福克岛标准时间': '(UTC+11:30) Norfolk Island',
    '(UTC+12)奥克兰,惠灵顿': '(UTC+12) Auckland, Wellington',
    '(UTC+12)斐济': '(UTC+12) Fiji',
    '(UTC+12)马加丹': '(UTC+12) Magadan',
    '(UTC+12)协调世界时+12': '(UTC+12) Coordinated Universal Time+12',
    '(UTC+12:45)查塔姆群岛标准时间': '(UTC+12:45) Chatham Islands',
    '(UTC+13)努库阿洛法': '(UTC+13) Nuku\'alofa',
    '(UTC+14)基里巴斯': '(UTC+14) Kiribati',

    '(UTC-11)中途岛，帕果帕果': '(UTC-11) Midway, Pago Pago',
    '(UTC-11)纽埃': '(UTC-11) Niue',
    '(UTC-10)阿达克': '(UTC-10) Adak',
    '(UTC-10)夏威夷－阿留申标准时间': '(UTC-10) Hawaii-Aleutian',
    '(UTC-10)火奴鲁鲁': '(UTC-10) Honolulu',
    '(UTC-10)拉罗汤加，塔希提岛': '(UTC-10) Rarotonga, Tahiti',
    '(UTC-9:30)马克萨斯群岛': '(UTC-9:30) Marquesas Islands',
    '(UTC-9)安克雷奇，朱诺，梅特拉卡特拉，诺姆，西特卡，雅库塔特': '(UTC-9) Anchorage, Juneau, Metlakatla, Nome, Sitka, Yakutat',
    '(UTC-9)甘比尔': '(UTC-9) Gambier',
    '(UTC-8)道森，洛杉矶，蒂华纳，温哥华，怀特霍斯': '(UTC-8) Dawson, Los Angeles, Tijuana, Vancouver, Whitehorse',
    '(UTC-8)皮特克恩': '(UTC-8) Pitcairn',
    '(UTC-7)博伊西，剑桥湾，丹佛，埃德蒙顿，奥吉纳加': '(UTC-7) Boise, Cambridge Bay, Denver, Edmonton, Ojinaga',
    '(UTC-7)奇瓦瓦，马萨特兰': '(UTC-7) Chihuahua, Mazatlan',
    '(UTC-7)克丽顿，道森克里克，纳尔逊堡，赫莫西略，凤凰城': '(UTC-7) Creston, Dawson Creek, Fort Nelson, Hermosillo, Phoenix',
    '(UTC-6)巴伊亚班德拉斯，梅里达，墨西哥城，蒙特雷': '(UTC-6) Bahia Banderas, Merida, Mexico City, Monterrey',
    '(UTC-6)伯利兹，哥斯达黎加，萨尔瓦多，危地马拉，马那瓜': '(UTC-6) Belize, Costa Rica, El Salvador, Guatemala, Managua',
    '(UTC-6)芝加哥，马塔莫罗斯，新塞勒姆，雷尼河，温尼伯': '(UTC-6) Chicago, Matamoros, New Salem, Rainy River, Winnipeg',
    '(UTC-6)复活节岛': '(UTC-6) Easter Island',
    '(UTC-6)加拉帕戈斯': '(UTC-6) Galapagos',
    '(UTC-5)阿蒂科坎，坎昆，开曼，牙买加，巴拿马': '(UTC-5) Atikokan, Cancun, Cayman, Jamaica, Panama',
    '(UTC-5)波哥大，埃里伦佩，瓜亚基尔，利马，里奥布兰科': '(UTC-5) Bogota, Eirunepe, Guayaquil, Lima, Rio Branco',
    '(UTC-5)底特律，拿骚，纽约，太子港，多伦多': '(UTC-5) Detroit, Nassau, New York, Port-au-Prince, Toronto',
    '(UTC-5)哈瓦那': '(UTC-5) Havana',
    '(UTC-4)勃朗萨布隆，格林纳达，西班牙港，波多黎各，圣多明各': '(UTC-4) Blanc-Sablon, Grenada, Port of Spain, Puerto Rico, Santo Domingo',
    '(UTC-4)坎波格兰德，加拉加斯，圭亚那，拉巴斯，波尔图韦略': '(UTC-4) Campo Grande, Caracas, Guyana, La Paz, Porto Velho',
    '(UTC-4)格拉斯湾，鹅湾，哈利法克斯，百慕大': '(UTC-4) Glace Bay, Goose Bay, Halifax, Bermuda',
    '(UTC-3:30)圣约翰斯': '(UTC-3:30) St. John\'s',
    '(UTC-3)布宜诺斯艾利斯，圣路易斯，马塞奥，蒙得维的亚，帕拉马里博': '(UTC-3) Buenos Aires, San Luis, Maceio, Montevideo, Paramaribo',
    '(UTC-3)戈塔布': '(UTC-3) Godthab',
    '(UTC-3)米克隆': '(UTC-3) Miquelon',
    '(UTC-2)诺罗尼亚，南乔治亚岛': '(UTC-2) Noronha, South Georgia',
    '(UTC-1)佛得角': '(UTC-1) Cape Verde',
    '(UTC-1)斯科尔斯比松德，亚速尔群岛': '(UTC-1) Scoresbysund, Azores',
    '(UTC+0)达喀尔，蒙罗维亚，圣多美，丹马克斯沙文，雷克雅未克': '(UTC+0) Dakar, Monrovia, Sao Tome, Danmarkshavn, Reykjavik',
    '(UTC+0)协调世界时': '(UTC+0) Coordinated Universal Time',
    '(UTC+0)加那利，法罗，马德拉，里斯本': '(UTC+0) Canary, Faroe, Madeira, Lisbon',
    '(UTC+0)根西岛，马恩岛，泽西岛，伦敦': '(UTC+0) Guernsey, Isle of Man, Jersey, London',
    '(UTC+1)阿布贾，阿尔及尔，突尼斯': '(UTC+1) Abuja, Algiers, Tunis',
    '(UTC+1)班吉，布拉柴维尔，杜阿拉，金沙萨，拉各斯': '(UTC+1) Bangui, Brazzaville, Douala, Kinshasa, Lagos',
    '(UTC+1)卡萨布兰卡，阿伊恩': '(UTC+1) Casablanca, El Aaiun',
    '(UTC+1)伯尔尼，柏林，哥本哈根，马德里，巴黎，罗马': '(UTC+1) Bern, Berlin, Copenhagen, Madrid, Paris, Rome',
    '(UTC+1)都柏林': '(UTC+1) Dublin',
    '(UTC+2)布兰太尔，布琼布拉，哈博罗内，哈拉雷': '(UTC+2) Blantyre, Bujumbura, Gaborone, Harare',
    '(UTC+2)开罗，特里波利，加里宁格勒': '(UTC+2) Cairo, Tripoli, Kaliningrad',
    '(UTC+2)基希讷乌': '(UTC+2) Chisinau',
    '(UTC+2)雅典，布加勒斯特，赫尔辛基，基辅，马里利亚哈姆': '(UTC+2) Athens, Bucharest, Helsinki, Kyiv, Mariehamn',
    '(UTC+2)加沙，希伯伦': '(UTC+2) Gaza, Hebron',
    '(UTC+2)约翰内斯堡，马塞卢，姆巴巴内': '(UTC+2) Johannesburg, Maseru, Mbabane',
    '(UTC+2)特罗尔': '(UTC+2) Troll',
    '(UTC+3)亚的斯亚贝巴，阿斯马拉，达累斯萨拉姆，内罗毕，塔那那利佛': '(UTC+3) Addis Ababa, Asmara, Dar es Salaam, Nairobi, Antananarivo',
    '(UTC+3)莫斯科，辛菲罗波尔': '(UTC+3) Moscow, Simferopol',
    '(UTC+3)巴格达，科威特，卡塔尔，利雅得，伊斯坦布尔': '(UTC+3) Baghdad, Kuwait, Qatar, Riyadh, Istanbul',
    '(UTC+4)迪拜，阿斯特拉罕，萨拉托夫，马海，毛里求斯': '(UTC+4) Dubai, Astrakhan, Saratov, Mahe, Mauritius',
    '(UTC+5)卡拉奇': '(UTC+5) Karachi',
    '(UTC+5)阿克托贝，杜尚贝，撒马尔罕，塔什干，叶卡捷琳堡': '(UTC+5) Aqtobe, Dushanbe, Samarkand, Tashkent, Yekaterinburg',
    '(UTC+5:30)科伦坡': '(UTC+5:30) Colombo',
    '(UTC+6)沃斯托克，阿拉木图，达卡，鄂木斯克，廷布': '(UTC+6) Vostok, Almaty, Dhaka, Omsk, Thimphu',
    '(UTC+6:30)仰光，科科斯': '(UTC+6:30) Yangon, Cocos',
    '(UTC+7)河内，曼谷，巴瑙尔，胡志明，新西伯利亚': '(UTC+7) Hanoi, Bangkok, Barnaul, Ho Chi Minh, Novosibirsk',
    '(UTC+7)雅加达，坤甸': '(UTC+7) Jakarta, Pontianak',
    '(UTC+8)文莱，伊尔库茨克，吉隆坡，新加坡，乌兰巴托': '(UTC+8) Brunei, Irkutsk, Kuala Lumpur, Singapore, Ulaanbaatar',
    '(UTC+8)中国澳门，上海，中国台北': '(UTC+8) Macau, Shanghai, Taipei',
    '(UTC+8)望加锡': '(UTC+8) Makassar',
    '(UTC+8)马尼拉': '(UTC+8) Manila',
    '(UTC+8:45)尤克拉': '(UTC+8:45) Eucla',
    '(UTC+9)奇塔，帝力，坎迪加，雅库茨克，帕劳': '(UTC+9) Chita, Dili, Khandyga, Yakutsk, Palau',
    '(UTC+9)查亚普拉': '(UTC+9) Jayapura',
    '(UTC+9)平壤，首尔': '(UTC+9) Pyongyang, Seoul',
    '(UTC+9:30)阿德莱德，布罗肯希尔': '(UTC+9:30) Adelaide, Broken Hill',
    '(UTC+10)布里斯班，林德曼': '(UTC+10) Brisbane, Lindeman',
    '(UTC+10)柯里，霍巴特，墨尔本，悉尼': '(UTC+10) Currie, Hobart, Melbourne, Sydney',
    '(UTC+10)杜蒙特杜尔维尔，乌斯特内拉，弗拉迪沃斯托克，楚克，莫尔斯比港': '(UTC+10) Dumont d\'Urville, Ust-Nera, Vladivostok, Chuuk, Port Moresby',
    '(UTC+10)关岛，塞班岛': '(UTC+10) Guam, Saipan',
    '(UTC+11)罗德豪维岛': '(UTC+11) Lord Howe Island',
    '(UTC+11)麦格理，马加丹，萨哈林，斯莱德内科林斯克，布干维尔': '(UTC+11) Macquarie, Magadan, Sakhalin, Srednekolymsk, Bougainville',
    '(UTC+12)富纳富蒂，夸贾林，马朱罗，瑙鲁': '(UTC+12) Funafuti, Kwajalein, Majuro, Nauru',
    '(UTC+12)惠灵顿，麦克默多，奥克兰': '(UTC+12) Wellington, McMurdo, Auckland',
    '(UTC+12:45)查塔姆岛': '(UTC+12:45) Chatham Island',
    '(UTC+13)萨摩亚': '(UTC+13) Samoa',
    '(UTC+13)恩德伯里，法考福，通塔普': '(UTC+13) Enderbury, Fakaofo, Tongatapu',
    '(UTC+14)基里蒂马蒂': '(UTC+14) Kiritimati',
  });

  // Short keys allowed inside longer text despite being under 3 characters.
  const PIECES_OK = ['本机', '带宽', '频段', '选项', '：', '，', '。', '（', '）', '；', '？', '！'];

  const CJK = /[㐀-鿿。！（），：；？]/;
  const escape = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

  const PATTERNS = [];
  const PLAIN = {};
  for (const [k, v] of Object.entries(DICT)) {
    if (!k.includes('{$')) { PLAIN[k] = v; continue; }
    const names = [];
    const re = escape(k).replace(/\\\{\\\$(\w+)\\\}/g, (_, n) => { names.push(n); return '(.+?)'; });
    PATTERNS.push([new RegExp('^' + re + '$'), names, v]);
  }
  const pieceKeys = Object.keys(PLAIN)
    .filter((k) => k.length >= 3 || PIECES_OK.includes(k))
    .sort((a, b) => b.length - a.length);
  const PIECES = new RegExp(pieceKeys.map(escape).join('|'), 'g');

  function whole(t) {
    if (PLAIN[t] !== undefined) return PLAIN[t];
    for (const [re, names, v] of PATTERNS) {
      const m = t.match(re);
      if (m) return v.replace(/\{\$(\w+)\}/g, (_, n) => tr(m[names.indexOf(n) + 1]));
    }
    return null;
  }

  function tr(s) {
    if (!s || !CJK.test(s)) return s;
    const t = s.replace(/\s+/g, ' ').trim();
    const lead = s.match(/^\s*/)[0], trail = s.match(/\s*$/)[0];
    const w = whole(t);
    if (w !== null) return lead + w + trail;
    // Pieces next to letters/digits or other Chinese get a space, so
    // "手工设置外网带宽" doesn't become "Set manuallyinternet bandwidth".
    const r = t.replace(PIECES, (m, off, str) => {
      let x = PLAIN[m];
      const prev = str[off - 1], next = str[off + m.length];
      if (prev && /[A-Za-z0-9㐀-鿿]/.test(prev) && /^[A-Za-z]/.test(x)) x = ' ' + x;
      if (next && /[A-Za-z0-9㐀-鿿]/.test(next) && /[A-Za-z]$/.test(x)) x += ' ';
      return x;
    }).replace(/ {2,}/g, ' ');
    return CJK.test(r) ? s : lead + r + trail;
  }

  const ATTRS = ['placeholder', 'title', 'alt', 'aria-label', 'value'];

  function fixAttrs(el) {
    for (const a of ATTRS) {
      // value: only on buttons; never rewrite what a user typed into a field
      // or what a form sends back (e.g. <option value="客厅">).
      if (a === 'value' && !(el.tagName === 'INPUT' && /^(button|submit|reset)$/i.test(el.type))) continue;
      const v = el.getAttribute(a);
      if (v) { const n = tr(v); if (n !== v) el.setAttribute(a, n); }
    }
  }

  function fixText(node) {
    const p = node.parentElement;
    if (p && (p.tagName === 'SCRIPT' || p.tagName === 'STYLE' || p.tagName === 'TEXTAREA')) return;
    const v = node.nodeValue;
    let n = tr(v);
    // 关闭 is "Close" on buttons but "Off" when labelling a radio button/checkbox.
    const label = p && p.closest('label');
    if (v.trim() === '关闭' && label && label.querySelector('input[type=radio], input[type=checkbox]'))
      n = v.replace('关闭', 'Off');
    if (n !== v) node.nodeValue = n;
  }

  function walk(root) {
    if (root.nodeType === Node.TEXT_NODE) return fixText(root);
    if (root.nodeType !== Node.ELEMENT_NODE) return;
    fixAttrs(root);
    const w = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT);
    for (let n; (n = w.nextNode());) {
      if (n.nodeType === Node.TEXT_NODE) fixText(n); else fixAttrs(n);
    }
  }

  function fixTitle() {
    const n = tr(document.title);
    if (n !== document.title) document.title = n;
  }

  new MutationObserver((muts) => {
    for (const m of muts) {
      if (m.type === 'characterData') fixText(m.target);
      else if (m.type === 'attributes') fixAttrs(m.target);
      else m.addedNodes.forEach(walk);
    }
    fixTitle();
  }).observe(document, {
    subtree: true, childList: true, characterData: true,
    attributes: true, attributeFilter: ATTRS,
  });

  // alert() and confirm() texts (e.g. rsp.msg errors) aren't in the page.
  for (const f of ['alert', 'confirm']) {
    const orig = window[f];
    window[f] = function (msg) { return orig.call(this, tr(String(msg))); };
  }

  // Login page: the form has only a password field marked autocomplete=off
  // (the page always logs in as "admin"), so Brave doesn't treat it as a
  // login and won't save or fill it. Give it a username field and proper
  // autocomplete hints.
  function fixLoginForm() {
    const pwd = document.querySelector('#rtloginform input[type=password]');
    if (!pwd || pwd.form.querySelector('input[autocomplete=username]')) return;
    pwd.setAttribute('autocomplete', 'current-password');
    const user = document.createElement('input');
    Object.assign(user, { type: 'text', name: 'username', value: 'admin', tabIndex: -1 });
    user.setAttribute('value', 'admin');
    user.setAttribute('autocomplete', 'username');
    user.setAttribute('aria-hidden', 'true');
    user.style.cssText = 'position:absolute;left:-9999px;width:1px;height:1px;opacity:0';
    pwd.form.insertBefore(user, pwd.form.firstChild);
  }
  // Tampermonkey may inject after the page has loaded.
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fixLoginForm);
  else fixLoginForm();

  if (document.documentElement) walk(document.documentElement);
  fixTitle();
})();
