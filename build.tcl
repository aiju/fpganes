set origin [file dirname [info script]]
create_project -force fpganes $origin/build
set obj [get_projects fpganes]
set part "xc7z015clg485-1" 
set_property "default_lib" "xil_defaultlib" $obj
set_property "part" $part $obj

set_property "simulator_language" "Verilog" $obj
set_property "source_mgmt_mode" "DisplayOnly" $obj
set_property "target_language" "Verilog" $obj

#create_fileset -srcset sources_1

set obj [get_filesets sources_1]
set files [ glob $origin/*.v $origin/dpout/*.v ]
add_files -norecurse -fileset $obj $files

import_ip [ glob $origin/dpout/*.xci ]

set obj [get_filesets sources_1]
set_property "top" "top" $obj

#create_fileset -constrset constrs_1

set obj [get_filesets constrs_1]

set_property "file_type" "XDC" [add_files -norecurse -fileset $obj "$origin/dpout/constrs.xdc"]
