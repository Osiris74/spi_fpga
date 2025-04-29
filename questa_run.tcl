# 1. Удаление предыдущих сессий
vlib work
vmap work work

# Процедура для рекурсивного поиска .sv файлов
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

# 3. Оптимизация с сохранением видимости
vopt work.tb_mosi -o tb_opt +acc

# 4. Запуск симуляции и сохранение WLF
vsim -gui -wlf wave.wlf tb_opt

# 5. Открыть окно Wave и добавить все сигналы
view wave
add wave -position insertpoint /*

# 6. Запустить симуляцию до конца
run -all


# To start manually: vsim -do questa_run.tcl