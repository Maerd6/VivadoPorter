from argparse import ArgumentParser
from os import walk, path, makedirs, mkdir
from shutil import copy, rmtree as shutil_rmtree

def main():
    parser = ArgumentParser(
        description="Pack Vivado project into a portable form."
    )

    parser.add_argument("-t", "--top", action="store", help="Name of top module.", required=True)
    parser.add_argument("-p", "--part", action="store", help="Target FPGA part number.", required=True)
    parser.add_argument("-d", "--dir", action="store", help="Direction of source code.", required=True)
    parser.add_argument("-s", "--svf", action="store_true", help="Generate SVF file.")

    args = parser.parse_args()

    #创建工程文件夹
    package_path = f"./{args.top}_Package"
    try:
        # 如果文件夹已存在，删除该文件
        if path.exists(package_path):
            shutil_rmtree(package_path)
            print(f"已删除现有文件: {package_path}")
        
        # 创建文件所在的目录（如果不存在）
        if not path.exists(package_path):
            makedirs(package_path)
        if not path.exists(package_path + "/verilog"):
            makedirs(package_path + "/verilog")
        if not path.exists(package_path + "/constraints"):
            makedirs(package_path + "/constraints")
        if not path.exists(package_path + "/ip"):
            makedirs(package_path + "/ip")

    except Exception as e:
        print(f"创建Package失败: {e}")
        return False
    
    # 创建 tcl 文件
    create_tcl(args)


def create_tcl(args):
    create_non_pro_tcl(args)


def create_non_pro_tcl(args):
    """
    创建一个文件。如果文件已存在，则删除后重新创建。
    
    top:
        top (str): 顶层模块名称
    part:
        part (str): 芯片型号
    dir:
        dir (str): 源代码路径
    svf:
        svf (bool): 是否生成SVF文件
    
    Returns:
        bool: 创建成功返回True，否则返回False
    """
    content=""
    part = args.part
    top = args.top
    dir = args.dir
    package_path = f"./{top}_Package"
    non_project_tcl_path = f"{package_path}/non_project.tcl"

    # 调用collect_files_by_type函数，并用列表接收返回值
    v_files, xdc_files, xci_files, else_files = collect_and_copy_files_by_type(dir, package_path)

    #创建non_project.tcl文件
    try:
        directory = path.dirname(non_project_tcl_path)
        if directory and not path.exists(directory):
            makedirs(directory)
    except Exception as e:
        print(f"创建non_project.tcl失败: {e}")
        return False
        
    # 添加芯片型号
    content =content + f"#set fpga core\n"
    content =content + f"set part {part}\n\n"
        
    #添加线程数
    content =content + f"#set thread number\n"
    content =content + f"set_param general.maxThreads 8\n\n"

    #添加verilog文件
    content =content + f"#read verilog file\n"
    for v_file in v_files:
        content = content + f"read_verilog ./verilog/{v_file}.v\n"
    content = content + "\n"
        
    #添加xdc文件
    content =content + f"#read xdc file\n"
    for xdc_file in xdc_files:
        content = content + f"read_xdc ./constraints/{xdc_file}.xdc\n"
    content = content + "\n"

    #添加并综合ip文件
    content =content + f"#read & generate & synthesize & read ip file\n"
    for ip_file in xci_files:
        content = content + f"if {{ [file exists ./src/ip/{ip_file}.dcp] }} {{\n"
        content = content + f"  puts \"{ip_file} already exits\"\n"
        content = content + f"  read_checkpoint ./ip/{ip_file}/{ip_file}.dcp\n"
        content = content + f"}} else {{\n"
        content = content + f"  read_ip ./ip/{ip_file}/{ip_file}.xci\n"
        content = content + f"  generate_target all [get_ips {ip_file}]\n"
        content = content + f"  synth_ip -force [get_ips {ip_file}]\n"
        content = content + f"}}\n\n"

    #综合设计
    content = content + f"#synthesize design\n"
    content = content + f"synth_design -top {top} -part $part\n\n"

    #实现设计
    content = content + f"#implementation\n"
    content = content + f"opt_design\n"
    content = content + f"place_design\n"
    content = content + f"route_design\n\n"

    #生成比特流
    content = content + f"#generate bitstream\n"
    content = content + f"write_bitstream -force ./{top}.bit\n\n"

    #generate SVF file
    if args.svf:
        content = content + f"#generate SVF file\n"
        content = content + f"open_hw\n"
        content = content + f"connect_hw_server\n"
        content = content + f"create_hw_target my_svf_target\n"
        content = content + f"open_hw_target [get_hw_targets -regexp .*/my_svf_target]\n"
        content = content + f"set device0 [create_hw_device -part $part]\n"
        content = content + f"set_property PROGRAM.FILE {top}.bit $device0\n"
        content = content + f"program_hw_devices -force -svf_file {top}.svf $device0\n"

    # 创建文件
    with open(non_project_tcl_path, 'w', encoding='utf-8') as f:
        f.write(content)
        
    print(f"文件已成功创建: {non_project_tcl_path}")
    return True

    
def collect_and_copy_files_by_type(src, dst):
    v_files = []
    xdc_files = []
    xci_files = []
    else_files = []

    for root, dirs, files in walk(src):
        for file in files:
            name, ext = path.splitext(file)

            # 匹配文件类型
            if ext == ".v":
                v_files.append(name)
                copy(f'{src}/{file}', f'{dst}/verilog/{file}')
            elif ext == ".xdc":
                xdc_files.append(name)
                copy(f'{src}/{file}', f'{dst}/constraints/{file}')
            elif ext == ".xci":
                xci_files.append(name)
                mkdir(f'{dst}/ip/{name}')
                copy(f'{src}/{file}', f'{dst}/ip/{name}/{file}')
            else:
                else_files.append(name)
                print(f"未处理的文件类型: {file}")

    return v_files, xdc_files, xci_files, else_files



if __name__ == "__main__":
    main()