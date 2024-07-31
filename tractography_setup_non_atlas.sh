#!/bin/bash
# Do all the setup for people who are not part of the atlas (largely similar code to tract_atlas_AW.sh)

# First set up folders
# Basically do all the steps short of making these subjects actually part of the template. 
echo "beginning script..."
sleep 15
declare -a subject=(
    # "02-CON-005"
    # "02-CON-138"
    # "02-CON-139"
    # "02-CON-141"
    # "02-CON-159"
    # "02-CON-160"
    # "02-CON-162"
    # "02-CON-163"
    # "02-CON-165"
    #
    # "02-PPM-010"
    # "02-PPM-072"
    # "02-PPM-111"
    # "02-PPM-112"
    # "02-PPM-129"
    # "02-PPM-136"
    #
    # "02-PPM-149"
    "02-PPM-154"
    "02-PPM-155"
    "02-PPM-183"
    "02-PPM-192"
    "02-PPM-201"
    "02-PPM-206"
    "02-PPM-222"
    # #
    # "02-RRM-009"
    # "02-RRM-034"
    # "02-RRM-052"
    # "02-RRM-055"
    # "02-RRM-093"
    # "02-RRM-116"
    # "02-RRM-125"
    # "02-RRM-133"
    # "02-RRM-137"
    # "02-RRM-144"
    # "02-RRM-145"
    # "02-RRM-146"
    # "02-RRM-147"
    # "02-RRM-148"
    # "02-RRM-150"
    # "02-RRM-151"
    # "02-RRM-152"
    # "02-RRM-168"
    # "02-RRM-170"
    "02-RRM-171"
    "02-RRM-172"
    "02-RRM-173"
    "02-RRM-174"
    "02-RRM-176"
    "02-RRM-178"
    "02-RRM-180"
    "02-RRM-181"
    "02-RRM-186"
    "02-RRM-194"
    "02-RRM-196"
    "02-RRM-198"
    "02-RRM-208"
    "02-RRM-209"
    "02-RRM-210"
    # "02-RRM-214"
    # "02-RRM-215"
    # "02-RRM-217"
    # "02-RRM-219"
    # "02-RRM-221"
    # #
    # "02-RIS-022"
    # "02-RIS-054"
    # "02-RIS-123"
    # "02-RIS-124"
    # "02-RIS-158"
    "02-RIS-161"
    "02-RIS-177"
    "02-RIS-184"
    "02-RIS-185"
    "02-RIS-200"
    "02-RIS-202"
    "02-RIS-204"
    "02-RIS-211"
)

# mdd_in="MDD/Inputs" #Where the DTI-B.nii.gz file lives
# mdd_processed="MDD/processed" #Where the FA/MD data lives
tract="Tractography" #New folder you will create
# ants_mwf_mdd="ants/CALIPR_MDD" #Where the MWI->DTI registered data lives
base_folder='/data/ubcitm10/awu/by_patient_all_data'
# assumes group tractography folder is already made by running tract_atlas_AW.sh script
group_tract='/data/ubcitm10/awu/by_patient_all_data/group_tractography'

num_threads=6

echo 'Checking if group_tractography folder exists:'
if [ ! -d "$group_tract" ]; then
    echo "Error: The 'group tractography' folder does not exist. Please create it first."
    exit 1
fi
echo 'It exists! proceeding...'

# Check if the response files exist
response_wm="${group_tract}/group_average_response_wm.txt"
response_gm="${group_tract}/group_average_response_gm.txt"
response_csf="${group_tract}/group_average_response_csf.txt"
echo 'checking if responses exist:'
if [ ! -f "$response_wm" ] || [ ! -f "$response_gm" ] || [ ! -f "$response_csf" ]; then
    echo "Error: One or more response files do not exist. Please create them first."
    exit 1
fi
echo "Response files exist. Proceeding..."

#Make a new folder in each subject for tractography stuff
##Move data into folder
echo "making folders"
for i in "${subject[@]}"; do
    echo "The current subject is: " ${i}
    mkdir -p ${base_folder}/${i}/Tractography
    cp ${base_folder}/${i}/DTI/M0/DTI-B.nii.gz ${base_folder}/${i}/${tract}/${i}_DTI-B.nii.gz #This is your DTI-B.nii.gz
    # NOTE: need to change these file names when it comes to it, just a proof of concept for now
    cp ${base_folder}/${i}/DTI/M0/wp.bval ${base_folder}/${i}/${tract}/${i}_wp.bval 
    cp ${base_folder}/${i}/DTI/M0/wp.bvec ${base_folder}/${i}/${tract}/${i}_wp.bvec 
    echo "Next subject..."
done

echo 'Making response Functions...'
##Create "response functions" for 3 tissue types to further do MSMT-CSD
for i in "${subject[@]}"; do
    echo "The current subject is: " ${i}
    dwi2response dhollander ${base_folder}/${i}/${tract}/${i}_DTI-B.nii.gz ${base_folder}/${i}/${tract}/response_wm.txt ${base_folder}/${i}/${tract}/response_gm.txt ${base_folder}/${i}/${tract}/response_csf.txt -fslgrad ${base_folder}/${i}/${tract}/${i}_wp.bvec ${base_folder}/${i}/${tract}/${i}_wp.bval -info -nthreads ${num_threads}
    echo "Next subject..."
done

# Then average these response functions for the whole group and put it into the new group_tractography folder
# need to add the rest of the subjects to this as well...
# mkdir group_tractography
# echo "Taking response mean for whole group..."
# responsemean ${base_folder}/02-PPM-010/Tractography/response_wm.txt ${group_tract}/group_average_response_wm.txt 
# responsemean ${base_folder}/02-PPM-010/Tractography/response_gm.txt ${group_tract}/group_average_response_gm.txt 
# responsemean ${base_folder}/02-PPM-010/Tractography/response_csf.txt ${group_tract}/group_average_response_csf.txt

##Some other little steps (also done in the tract_atlas_AW.sh file)
for i in "${subject[@]}"; do
    echo "The current subject is: " ${i}
    #Upsample the 3mm images to 1.25mm as recommended as this apparently improves template building
    echo 'Upsampling images...'
    mrgrid ${base_folder}/${i}/${tract}/${i}_DTI-B.nii.gz regrid -vox 1.25 ${base_folder}/${i}/Tractography/${i}_DTI-B_upsampled.nii.gz -force

    #Get brain mask from upsampled image
    echo 'Brain mask creation...'
    dwi2mask ${base_folder}/${i}/Tractography/${i}_DTI-B_upsampled.nii.gz -fslgrad ${base_folder}/${i}/${tract}/${i}_wp.bvec ${base_folder}/${i}/${tract}/${i}_wp.bval -info -nthreads ${num_threads} ${base_folder}/${i}/${tract}/${i}_mask_upsampled.nii.gz -force

    #Get FOD estimate
    echo 'FOD estimating...'
    dwi2fod msmt_csd ${base_folder}/${i}/Tractography/${i}_DTI-B_upsampled.nii.gz -fslgrad ${base_folder}/${i}/${tract}/${i}_wp.bvec ${base_folder}/${i}/${tract}/${i}_wp.bval ${group_tract}/group_average_response_wm.txt ${base_folder}/${i}/Tractography/wmfod.nii.gz ${group_tract}/group_average_response_gm.txt ${base_folder}/${i}/Tractography/gm.nii.gz  ${group_tract}/group_average_response_csf.txt ${base_folder}/${i}/Tractography/csf.nii.gz -mask ${base_folder}/${i}/Tractography/${i}_mask_upsampled.nii.gz -force -nthreads ${num_threads}

    ##Joint bias field correction and intensity normalization. Based on https://community.mrtrix.org/t/error-using-mtnormalise/1111/4 I removed GM from this normalization because that was causing non-positive errors
    ##I guess because the GM FODs were ~0 or -ve? I guess its to do with voxel size/partial voluming so that 2 tissue works better than 3.
    echo 'Joint bias field correction / normalization...'
    mtnormalise ${base_folder}/${i}/Tractography/wmfod.nii.gz ${base_folder}/${i}/Tractography/wmfod_norm.nii.gz ${base_folder}/${i}/Tractography/csf.nii.gz ${base_folder}/${i}/Tractography/csf_norm.nii.gz -mask ${base_folder}/${i}/Tractography/${i}_mask_upsampled.nii.gz -force
    echo "Next subject..."
done

##Register the subjects to the template
for i in "${subject[@]}"; do
    echo "The current subject is: " ${i}
    ##Register subject FOD images to FOD template
    echo 'Registering subject FOD images to FOD template...'
    mrregister ${base_folder}/${i}/Tractography/wmfod_norm.nii.gz -mask1 ${base_folder}/${i}/Tractography/${i}_mask_upsampled.nii.gz ${group_tract}/wmfod_template.nii.gz -nl_warp ${base_folder}/${i}/Tractography/subject2template_warp.nii.gz ${base_folder}/${i}/Tractography/template2subject_warp.nii.gz -force -nthreads ${num_threads}
    ##Transform masks into template space
    echo "transforming mask into template space..."
    mrtransform ${base_folder}/${i}/Tractography/${i}_mask_upsampled.nii.gz -warp ${base_folder}/${i}/Tractography/subject2template_warp.nii.gz -interp nearest -datatype bit ${base_folder}/${i}/Tractography/mask_upsampled_template_space.nii.gz -force
    echo "Next subject..."
done
echo "Script complete! :D"
# Get the current time when the script finishes
finish_time=$(date "+%Y-%m-%d %H:%M:%S")

echo "Script finished at: $finish_time"