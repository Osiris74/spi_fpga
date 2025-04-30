set output_dir "./sim_results"
file mkdir $output_dir

# 1. Delete previous sessions
vlib ${output_dir}/work
vmap work ${output_dir}/work

# Recursive search for .sv files
proc find_recursive { base_dir pattern } {
    set files [list]
    if {![file exists $base_dir]} {
        puts "Warning: Directory $base_dir does not exist."
        return $files
    }
    foreach dir [glob -nocomplain -directory $base_dir -type d *] {
        set sub_files [find_recursive $dir $pattern]
        foreach sub_file $sub_files {
            lappend files $sub_file
        }
    }
    set current_files [glob -nocomplain -directory $base_dir -type f $pattern]
    foreach current_file $current_files {
        lappend files $current_file
    }
    return $files
}

set src_files [find_recursive "./src" "*.sv"]

vlog -sv -work work {*}$src_files ./testbench/tb_mosi.sv

# 3. Optimization
vopt work.tb_mosi -o tb_opt +acc

# 4. Start simulation and saving WLF
vsim -gui \
    -wlf ${output_dir}/wave.wlf \
    -l ${output_dir}/simulation.log \
    tb_opt

# 5. Open Wave window + add all signals
view wave
add wave -position insertpoint /*

run -all


# To start manually: vsim -do questa_run.tcl