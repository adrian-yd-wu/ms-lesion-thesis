#!/bin/bash
# Creating a tractography atlas
# I used commands from https://github.com/MIC-DKFZ/TractSeg/blob/master/resources/Tractometry_documentation.md with a fix from
# https://github.com/MIC-DKFZ/TractSeg/issues/154 (using mrtrix's tckgen for tracking) since Tracking didn't work for me.
# Requires a folder with diffusion data (nii, bvals, bvecs). 
# Ok first we have pre-processed data (susceptibility, motion, eddy current corrected). We follow the mrtrix3 guide for making a population level template to do tractography on
# Following https://mrtrix.readthedocs.io/en/latest/fixel_based_analysis/mt_fibre_density_cross-section.html?highlight=population%20template until the part where tractography needs to be done
# when I start following the tractseg guide instead.

# First set up folders.
# Subjects listed here are the ones we use in the atlas.
echo "beginning script..."
sleep 30
declare -a subject=(
    "02-CON-005"
    "02-CON-138"
    "02-CON-139"
    "02-CON-141"
    "02-CON-159"
    # "02-CON-160"
    # "02-CON-162"
    # "02-CON-163"
    # "02-CON-165"
)

# mdd_in="MDD/Inputs" #This will be whatever folder holds your DTI-B.nii.gz data
# mdd_processed="MDD/processed" #This will be whatever folder holds your FA/MD maps
tract="Tractography" #A new folder you will create
# ants_mwf_mdd="ants/CALIPR_MDD" #This will be wherever you have registered MWI->DTI

# Create tractography atlas folders
# Folder name for where tractography atlas stuff will live
# base_folder="/data/ubcitm10/awu" # "/home/awu/Documents"
echo "making folders"
mkdir -p /data/ubcitm10/awu/by_patient_all_data/group_tractography 
# Subfolders
mkdir /data/ubcitm10/awu/by_patient_all_data/group_tractography/fod_input 
mkdir /data/ubcitm10/awu/by_patient_all_data/group_tractography/mask_input 

group_tract='/data/ubcitm10/awu/by_patient_all_data/group_tractography'
group_fod="/data/ubcitm10/awu/by_patient_all_data/group_tractography/fod_input"
group_mask="/data/ubcitm10/awu/by_patient_all_data/group_tractography/mask_input"
base_folder="/data/ubcitm10/awu/by_patient_all_data"
# base_folder="/Users/sharada/Documents/Projects/MDDE/V2" #This is the base folder that all subject folders live inside, and these scripts.

num_threads=6

# Make a new folder in each subject for tractography stuff!
# For each subject, copy over the diffusion data into a new tractography folder

echo "Directories successfully made, now starting to copy over DTI data"

for i in "${subject[@]}"; do
    echo "The current subject is: " ${i}
    folder_mdd_in="/data/ubcitm10/awu/by_patient_all_data/${i}/DTI/M0"

    mkdir -p ${base_folder}/${i}/Tractography
    # In my stuff, LTE_mc was basically DTI-B.nii.gz! Rename as needed. "LTE" is really the DTI stuff.
    cp ${folder_mdd_in}/DTI-B.nii.gz ${base_folder}/${i}/Tractography/${i}_DTI-B.nii.gz 
    # NOTE: need to change these file names when it comes to it, just a proof of concept for now
    cp ${folder_mdd_in}/wp.bval ${base_folder}/${i}/Tractography/${i}_wp.bval 
    cp ${folder_mdd_in}/wp.bvec ${base_folder}/${i}/Tractography/${i}_wp.bvec 
done

# Create "response functions" for 3 tissue types to further do MSMT-CSD-- also for special cases
echo "Now making response functions"
for i in "${subject[@]}"; do
    echo "The current subject is: " ${i}
    dwi2response dhollander ${base_folder}/${i}/Tractography/${i}_DTI-B.nii.gz ${base_folder}/${i}/Tractography/response_wm.txt ${base_folder}/${i}/Tractography/response_gm.txt ${base_folder}/${i}/Tractography/response_csf.txt -fslgrad ${base_folder}/${i}/Tractography/${i}_wp.bvec ${base_folder}/${i}/Tractography/${i}_wp.bval -info -nthreads ${num_threads}
done

# Then average these response functions for the whole group and put it into the new group_tractography folder
# need to add the rest of the subjects to this as well...
# mkdir group_tractography
echo "Taking response mean for whole group..."
responsemean ${base_folder}/02-CON-005/Tractography/response_wm.txt ${base_folder}/02-CON-138/Tractography/response_wm.txt ${base_folder}/02-CON-139/Tractography/response_wm.txt ${base_folder}/02-CON-141/Tractography/response_wm.txt ${base_folder}/02-CON-159/Tractography/response_wm.txt ${group_tract}/group_average_response_wm.txt 
responsemean ${base_folder}/02-CON-005/Tractography/response_gm.txt ${base_folder}/02-CON-138/Tractography/response_gm.txt ${base_folder}/02-CON-139/Tractography/response_gm.txt  ${base_folder}/02-CON-141/Tractography/response_gm.txt ${base_folder}/02-CON-159/Tractography/response_gm.txt ${group_tract}/group_average_response_gm.txt 
responsemean ${base_folder}/02-CON-005/Tractography/response_csf.txt ${base_folder}/02-CON-138/Tractography/response_csf.txt ${base_folder}/02-CON-139/Tractography/response_csf.txt  ${base_folder}/02-CON-141/Tractography/response_csf.txt ${base_folder}/02-CON-159/Tractography/response_csf.txt ${group_tract}/group_average_response_csf.txt 

##A few more steps for each subject
echo "processing data:"
for i in "${subject[@]}"; do
    echo "The current subject is: " ${i}
    # Upsample the lowers DTI images to 1.25mm as recommended as this apparently improves template building
    # This gives just a highres version of the same DTI data.
    echo "upsampling DTI"
    mrgrid ${base_folder}/${i}/Tractography/${i}_DTI-B.nii.gz regrid -vox 1.25 ${base_folder}/${i}/Tractography/${i}_DTI-B_upsampled.nii.gz

    # Get brain mask from upsampled image
    echo "Getting brain mask"
    dwi2mask ${base_folder}/${i}/Tractography/${i}_DTI-B_upsampled.nii.gz -fslgrad ${base_folder}/${i}/Tractography/${i}_wp.bvec ${base_folder}/${i}/Tractography/${i}_wp.bval -info -nthreads ${num_threads} ${base_folder}/${i}/Tractography/${i}_mask_upsampled.nii.gz

    # Get FOD estimate
    echo "Getting FOD estimates"
    dwi2fod msmt_csd ${base_folder}/${i}/Tractography/${i}_DTI-B_upsampled.nii.gz -fslgrad ${base_folder}/${i}/Tractography/${i}_wp.bvec ${base_folder}/${i}/Tractography/${i}_wp.bval ${group_tract}/group_average_response_wm.txt ${base_folder}/${i}/Tractography/wmfod.nii.gz ${group_tract}/group_average_response_gm.txt ${base_folder}/${i}/Tractography/gm.nii.gz  ${group_tract}/group_average_response_csf.txt ${base_folder}/${i}/Tractography/csf.nii.gz -mask ${base_folder}/${i}/Tractography/${i}_mask_upsampled.nii.gz -force -nthreads ${num_threads}

    # Joint bias field correction and intensity normalization. Based on https://community.mrtrix.org/t/error-using-mtnormalise/1111/4 I removed GM from this normalization because that was causing non-positive errors
    # I guess because the GM FODs were ~0 or -ve? I guess its to do with voxel size/partial voluming so that 2 tissue works better than 3.
    echo "Joint bias field correction and normalization"
    mtnormalise ${base_folder}/${i}/Tractography/wmfod.nii.gz ${base_folder}/${i}/Tractography/wmfod_norm.nii.gz ${base_folder}/${i}/Tractography/csf.nii.gz ${base_folder}/${i}/Tractography/csf_norm.nii.gz -mask ${base_folder}/${i}/Tractography/${i}_mask_upsampled.nii.gz -force

    # Symbolic link FOD images and masks into input folders-- not for special cases
    echo "Symbolic Linking FOD images and Masks"
    ln -sf ${base_folder}/${i}/Tractography/wmfod_norm.nii.gz ${group_fod}/${i}_PRE.nii.gz 
    ln -sf ${base_folder}/${i}/Tractography/${i}_mask_upsampled.nii.gz ${group_mask}/${i}_PRE.nii.gz 
    echo "Next subject ... "
done

# This step took about 2.5 hours for 6, 4 hours for 12 using 6 cores! Create a template from all the people's WM FODs. 
echo "Now creating population template: this will take a while..."
population_template ${group_fod} -mask_dir ${group_mask} ${group_tract}/wmfod_template.nii.gz -voxel_size 1.25 -nthreads ${num_threads}
echo "Done creating population template!"

# Create a warp for each subject to go from the subject's coordinate system/resolution to the template's, and then move over all the masks
# into template space.
echo "now warping a subject's coordinates to the template's"
for i in "${subject[@]}"; do
    echo "The current subject is: " ${i}
    # Register each subject's FOD images to the template
    # This also takes a while. Over an hour total!
    echo "begging registration..."
    mrregister ${base_folder}/${i}/Tractography/wmfod_norm.nii.gz -mask1 ${base_folder}/${i}/Tractography/${i}_mask_upsampled.nii.gz ${group_tract}/wmfod_template.nii.gz -nl_warp ${base_folder}/${i}/Tractography/subject2template_warp.nii.gz ${base_folder}/${i}/Tractography/template2subject_warp.nii.gz -force -nthreads ${num_threads}
    # Using that registration's warp, transform the masks into template space
    echo "transforming mask into template space..."
    mrtransform ${base_folder}/${i}/Tractography/${i}_mask_upsampled.nii.gz -warp ${base_folder}/${i}/Tractography/subject2template_warp.nii.gz -interp nearest -datatype bit ${base_folder}/${i}/Tractography/mask_upsampled_template_space.nii.gz -force
    echo "Next subject..."
done

# Put all the masks together in template space into one common mask. Open and check it (the template_mask file)\
echo "now putting masks all together..."
mrmath ${base_folder}/02-CON-005/Tractography/mask_upsampled_template_space.nii.gz ${base_folder}/02-CON-138/Tractography/mask_upsampled_template_space.nii.gz ${base_folder}/02-CON-139/Tractography/mask_upsampled_template_space.nii.gz ${base_folder}/02-CON-141/Tractography/mask_upsampled_template_space.nii.gz ${base_folder}/02-CON-159/Tractography/mask_upsampled_template_space.nii.gz min ${group_tract}/template_mask.nii.gz -datatype bit
# mrmath ${base_folder}/02-CON-138/Tractography/mask_upsampled_template_space_15.nii.gz ${base_folder}/02-CON-139/Tractography/mask_upsampled_template_space_15.nii.gz min ${group_tract}/template_mask_15.nii.gz -datatype bit

# Segment out tracts (can use as seed points)
# First convert the WM FOD template to peaks (still in template space) to be able to use with TractSeg

echo "Converting White matter FOD to peaks..." # problem child
sh2peaks -mask ${group_tract}/template_mask.nii.gz ${group_tract}/wmfod_template.nii.gz ${group_tract}/peaks_template.nii.gz # -debug
TractSeg -i ${group_tract}/peaks_template.nii.gz -o ${group_tract}/tractseg_output --output_type tract_segmentation # bundle segmentation #### stophere #####

#Create startpoints and endpoints (to use for tracking)
echo "Creating start/end points for tracking..."
TractSeg -i ${group_tract}/peaks_template.nii.gz -o ${group_tract}/tractseg_output --output_type endings_segmentation

#Create tract orientation maps to do tracking of segments
echo "Creating tract orientation maps..."
TractSeg -i ${group_tract}/peaks_template.nii.gz -o ${group_tract}/tractseg_output/ --output_type TOM

# #Use tckgen-- this generates a bundle for one tract
cd ${group_tract}/
# mkdir tractseg_output/tracking/ 

# If it works, this is the ideal Tractseg way to do it, usig the Tracking command (like in https://github.com/MIC-DKFZ/TractSeg/blob/master/resources/Tractometry_documentation.md):
echo "Tracing out white matter tracks... This will take a while?..."
Tracking -i ${group_tract}/peaks_template.nii.gz -o tractseg_output/

# If Tracking doesn't work, use this:
# tckgen -algorithm FACT tractseg_output/TOM/CST_left.nii.gz tractseg_output/tracking/CST_left.tck -seed_image tractseg_output/bundle_segmentations/CST_left.nii.gz -include tractseg_output/endings_segmentations/CST_left_e.nii.gz -include tractseg_output/endings_segmentations/CST_left_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/CST_right.nii.gz tractseg_output/tracking/CST_right.tck -seed_image tractseg_output/bundle_segmentations/CST_right.nii.gz -include tractseg_output/endings_segmentations/CST_right_e.nii.gz -include tractseg_output/endings_segmentations/CST_right_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/CC_1.nii.gz tractseg_output/tracking/CC_1.tck -seed_image tractseg_output/bundle_segmentations/CC_1.nii.gz -include tractseg_output/endings_segmentations/CC_1_e.nii.gz -include tractseg_output/endings_segmentations/CC_1_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/CC_2.nii.gz tractseg_output/tracking/CC_2.tck -seed_image tractseg_output/bundle_segmentations/CC_2.nii.gz -include tractseg_output/endings_segmentations/CC_2_e.nii.gz -include tractseg_output/endings_segmentations/CC_2_b.nii.gz -nthreads ${num_threads} -force
# tckgen -algorithm FACT tractseg_output/TOM/CC_3.nii.gz tractseg_output/tracking/CC_3.tck -seed_image tractseg_output/bundle_segmentations/CC_3.nii.gz -include tractseg_output/endings_segmentations/CC_3_e.nii.gz -include tractseg_output/endings_segmentations/CC_3_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/CC_4.nii.gz tractseg_output/tracking/CC_4.tck -seed_image tractseg_output/bundle_segmentations/CC_4.nii.gz -include tractseg_output/endings_segmentations/CC_4_e.nii.gz -include tractseg_output/endings_segmentations/CC_4_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/CC_5.nii.gz tractseg_output/tracking/CC_5.tck -seed_image tractseg_output/bundle_segmentations/CC_5.nii.gz -include tractseg_output/endings_segmentations/CC_5_e.nii.gz -include tractseg_output/endings_segmentations/CC_5_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/CC_6.nii.gz tractseg_output/tracking/CC_6.tck -seed_image tractseg_output/bundle_segmentations/CC_6.nii.gz -include tractseg_output/endings_segmentations/CC_6_e.nii.gz -include tractseg_output/endings_segmentations/CC_6_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/CC_7.nii.gz tractseg_output/tracking/CC_7.tck -seed_image tractseg_output/bundle_segmentations/CC_7.nii.gz -include tractseg_output/endings_segmentations/CC_7_e.nii.gz -include tractseg_output/endings_segmentations/CC_7_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/CC.nii.gz tractseg_output/tracking/CC.tck -seed_image tractseg_output/bundle_segmentations/CC.nii.gz -include tractseg_output/endings_segmentations/CC_e.nii.gz -include tractseg_output/endings_segmentations/CC_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/AF_left.nii.gz tractseg_output/tracking/AF_left.tck -seed_image tractseg_output/bundle_segmentations/AF_left.nii.gz -include tractseg_output/endings_segmentations/AF_left_e.nii.gz -include tractseg_output/endings_segmentations/AF_left_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/AF_right.nii.gz tractseg_output/tracking/AF_right.tck -seed_image tractseg_output/bundle_segmentations/AF_right.nii.gz -include tractseg_output/endings_segmentations/AF_right_e.nii.gz -include tractseg_output/endings_segmentations/AF_right_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/ATR_left.nii.gz tractseg_output/tracking/ATR_left.tck -seed_image tractseg_output/bundle_segmentations/ATR_left.nii.gz -include tractseg_output/endings_segmentations/ATR_left_e.nii.gz -include tractseg_output/endings_segmentations/ATR_left_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/ATR_right.nii.gz tractseg_output/tracking/ATR_right.tck -seed_image tractseg_output/bundle_segmentations/ATR_right.nii.gz -include tractseg_output/endings_segmentations/ATR_right_e.nii.gz -include tractseg_output/endings_segmentations/ATR_right_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/CG_left.nii.gz tractseg_output/tracking/CG_left.tck -seed_image tractseg_output/bundle_segmentations/CG_left.nii.gz -include tractseg_output/endings_segmentations/CG_left_e.nii.gz -include tractseg_output/endings_segmentations/CG_left_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/CG_right.nii.gz tractseg_output/tracking/CG_right.tck -seed_image tractseg_output/bundle_segmentations/CG_right.nii.gz -include tractseg_output/endings_segmentations/CG_right_e.nii.gz -include tractseg_output/endings_segmentations/CG_right_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/SLF_I_left.nii.gz tractseg_output/tracking/SLF_I_left.tck -seed_image tractseg_output/bundle_segmentations/SLF_I_left.nii.gz -include tractseg_output/endings_segmentations/SLF_I_left_e.nii.gz -include tractseg_output/endings_segmentations/SLF_I_left_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/SLF_I_right.nii.gz tractseg_output/tracking/SLF_I_right.tck -seed_image tractseg_output/bundle_segmentations/SLF_I_right.nii.gz -include tractseg_output/endings_segmentations/SLF_I_right_e.nii.gz -include tractseg_output/endings_segmentations/SLF_I_right_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/SLF_II_left.nii.gz tractseg_output/tracking/SLF_II_left.tck -seed_image tractseg_output/bundle_segmentations/SLF_II_left.nii.gz -include tractseg_output/endings_segmentations/SLF_II_left_e.nii.gz -include tractseg_output/endings_segmentations/SLF_II_left_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/SLF_II_right.nii.gz tractseg_output/tracking/SLF_II_right.tck -seed_image tractseg_output/bundle_segmentations/SLF_II_right.nii.gz -include tractseg_output/endings_segmentations/SLF_II_right_e.nii.gz -include tractseg_output/endings_segmentations/SLF_II_right_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/SLF_III_left.nii.gz tractseg_output/tracking/SLF_III_left.tck -seed_image tractseg_output/bundle_segmentations/SLF_III_left.nii.gz -include tractseg_output/endings_segmentations/SLF_III_left_e.nii.gz -include tractseg_output/endings_segmentations/SLF_III_left_b.nii.gz -nthreads ${num_threads}
# tckgen -algorithm FACT tractseg_output/TOM/SLF_III_right.nii.gz tractseg_output/tracking/SLF_III_right.tck -seed_image tractseg_output/bundle_segmentations/SLF_III_right.nii.gz -include tractseg_output/endings_segmentations/SLF_III_right_e.nii.gz -include tractseg_output/endings_segmentations/SLF_III_right_b.nii.gz -nthreads ${num_threads}

# Get the current time when the script finishes
finish_time=$(date "+%Y-%m-%d %H:%M:%S")

echo "Script finished at: $finish_time"


