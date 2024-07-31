#!/bin/bash
# Tractometry using TractSeg
# I used commands from https://github.com/MIC-DKFZ/TractSeg/blob/master/resources/Tractometry_documentation.md 
# Assumes we have already done the initial processing steps (and made an atlas as well). 
# Here we:
# - Register each subject's 2.2mm image to the atlas
# - Warp over everything from group_tractography/tractseg_output/ to each subject 
# - Generate tract profiles (tractometry) for MWF, FA, whatever else we need.

# First set up folders
echo "beginning script..."
sleep 30
# For ALL subjects, MS and those who weren't in the atlas.
declare -a subject=(
    "02-CON-005"
    "02-CON-138"
    "02-CON-139"
    "02-CON-141"
    "02-CON-159"
)

tract="Tractography" #We've already made this

base_folder="/data/ubcitm10/awu/by_patient_all_data" # "/home/awu/Documents"
# ants_mwf_mdd="ants/CALIPR_MDD" #The folder where MWI->DTI registered data lives
# group_fod="group_tractography/fod_input" #This is already made
# group_mask="group_tractography/mask_input"
# base_folder=/Users/sharada/Documents/Projects/MDDE/V2

# assumes group tractography folder is already made by running tract_atlas_AW.sh script
group_tract='/data/ubcitm10/awu/by_patient_all_data/group_tractography'

echo 'Checking if group_tractography folder exists:'
if [ ! -d "$group_tract" ]; then
    echo "Error: The 'group tractography' folder does not exist. Please create it first."
    exit 1
fi
echo 'It exists! proceeding...'

# Next, create a template volume to test registration with
# For that we take out the 1st volume of peaks_template.nii.gz
echo 'Creating template volume to test registration with...'
fslroi ${group_tract}/peaks_template.nii.gz ${group_tract}/template_1volume.nii.gz 0 1
# Clean up the background (remove NaNs)
echo 'Cleaning up NaNs'
fslmaths ${group_tract}/template_1volume.nii.gz -nan ${group_tract}/template_1volume.nii.gz


# Create warps to go from low-res diffusion space to atlas space. Remember we have already got warps from high-res diffusion to atlas!
for i in "${subject[@]}"; do
    echo "The current subject is: " ${i}
    tr_fld="/data/ubcitm10/awu/by_patient_all_data/${i}/Tractography"
    folder_ants="/data/ubcitm10/awu/by_patient_all_data/${i}/ants"
    # Register subject B0 images to template (the original 3mm version) so that there is a way to transform tracts into subject space again.
    # First create a B0 low-res image and B0 1.25mm image and register them.
    echo 'Creating low-res B0 image'
    fslroi ${tr_fld}/${i}_DTI-B.nii.gz ${tr_fld}/b0.nii.gz 0 1 ##This is the "low-res" version, extract the 0th volume from the DTI data.
    echo 'Creating hihg-res B0 image'
    fslroi ${tr_fld}/${i}_DTI-B_upsampled.nii.gz ${tr_fld}/b0_upsampled.nii.gz 0 1 ##The "high-res" version, extract 0th volume from upsampled DTI data.

    ############ TO FIX ###################################
    echo 'copying over brain extration mask'
    cp ${folder_ants}/DTI/BrainExtractionMask.nii.gz ${tr_fld}/BrainExtractionMask.nii.gz ##I called it 3mm for my old project-- the current data is actually 2.2mm
    echo 'Extracting just the brain from B0 low-res...'
    fslmaths ${tr_fld}/b0.nii.gz -mul ${tr_fld}/BrainExtractionMask.nii.gz ${tr_fld}/b0_masked.nii.gz ##Multiply b0 image by mask to keep just brain
    ##Register the lower res to the higher res image 
    echo 'Registering low to high res...'
    mrregister ${tr_fld}/b0_masked.nii.gz -mask1 ${tr_fld}/BrainExtractionMask.nii.gz ${tr_fld}/b0_upsampled.nii.gz -mask2 ${tr_fld}/${i}_mask_upsampled.nii.gz -nl_warp ${tr_fld}/downsampled_to_upsampled_warp.nii.gz ${tr_fld}/upsampled_to_downsampled_warp.nii.gz -force
    #######################################################

    ##Concatenate warps from template to native diffusion resolution (so you can go from template->subject's 2.2mm, or the other way)
    echo 'Concatenating warps from template --> native diffusion resolution...'
    transformcompose ${tr_fld}/template2subject_warp.nii.gz ${tr_fld}/upsampled_to_downsampled_warp.nii.gz ${tr_fld}/template_to_3mm_warp.nii.gz -template ${tr_fld}/b0_masked.nii.gz -force
    transformcompose ${tr_fld}/downsampled_to_upsampled_warp.nii.gz ${tr_fld}/subject2template_warp.nii.gz ${tr_fld}/downsampled_to_template_warp.nii.gz -template ${group_tract}/template_1volume.nii.gz -force

    #Apply warps and make sure they work!
    echo 'Applying warps...'
    mrtransform ${group_tract}/wmfod_template.nii.gz -warp ${tr_fld}/template_to_3mm_warp.nii.gz -interp nearest ${tr_fld}/template_to_subject_3mm.nii.gz -reorient_fod false -force
    mrtransform ${tr_fld}/b0.nii.gz -warp ${tr_fld}/downsampled_to_template_warp.nii.gz -interp nearest ${tr_fld}/subject_to_template.nii.gz -force
    echo "Next subject..."
done


#############
#Transform files based on the warps created above
for i in "${subject[@]}"; do
    echo "The current subject is: " ${i}
    tr_fld="/data/ubcitm10/awu/by_patient_all_data/${i}/Tractography"
    mkdir -p ${tr_fld}/tractseg ##Create a tractseg folder inside each subject's Tractography folder
    mkdir -p ${tr_fld}/tractseg/endings_segmentations
    mkdir -p ${tr_fld}/tractseg/tracking 
    subject_tracks=${tr_fld}/tractseg/tracking
    subject_endpoints=${tr_fld}/tractseg/endings_segmentations

    #Transform endpoints
    echo 'Transforming Endpoints...'
    cd ${group_tract}/tractseg_output/endings_segmentations 
    for file in *; do
        echo ${file}
        ##Apply the warp
        mrtransform ${file} -warp ${tr_fld}/template_to_3mm_warp.nii.gz -interp linear ${subject_endpoints}/${file} -force
    done

    #Transform actual tracts
    cd ${base_folder}
    cd ${group_tract}/tractseg_output/TOM_trackings 
    echo 'Transforming tracts...'
    for file in *; do
        echo ${file}
        #For some reason this needs to be the opposite warp!
        tcktransform ${file} ${tr_fld}/downsampled_to_template_warp.nii.gz ${subject_tracks}/${file} -force #This seems like the wrong thing but it's actually mtrtix's weird convention about warping
    done

    cd ${base_folder}
    echo "Next subject..."
done 
#####################

#Copy over metric maps in DTI space into the Tractography folder. Multiply by CSF mask to remove CSF!
for i in "${subject[@]}"; do

    echo "The current subject is: " ${i}
    tr_fld="/data/ubcitm10/awu/by_patient_all_data/${i}/Tractography"
    mwf_dti="/data/ubcitm10/awu/by_patient_all_data/${i}/ants/MWI_DTI" #The folder where MWI->DTI registered data lives
    folder_ants="/data/ubcitm10/awu/by_patient_all_data/${i}/ants"

    echo 'copying over csf mask...'
    cp ${folder_ants}/DTI/csf_mask.nii.gz ${tr_fld}/csf_mask.nii.gz

    echo 'Multiplying by csf mask...'
    fslmaths ${base_folder}/${i}/DTI/M0/DTI_FA.nii.gz -mul ${tr_fld}/csf_mask.nii.gz ${tr_fld}/fa.nii.gz #Copy over FA map, multiplied by non-CSF mask to remove CSF
    fslmaths ${base_folder}/${i}/ants/MWI_DTI/MWF.nii.gz -mul ${tr_fld}/csf_mask.nii.gz ${tr_fld}/mwf.nii.gz #Copy over MWF map (in DTI space), multiplied by non-CSF mask

    echo "Next subject..."
done

#If you have a metric map, profile it here.
for i in "${subject[@]}"; do
    echo "The current subject is: " ${i}
    tr_fld="/data/ubcitm10/awu/by_patient_all_data/${i}/Tractography"
    cd ${tr_fld}/tractseg

    # Do the actual tract profiling
    echo 'Beginning Tract Profiling on FA...'
    Tractometry -i tracking/ -o Tractometry_fa.csv -e endings_segmentations/ -s ${tr_fld}/fa.nii.gz --tracking_format tck 

    echo 'Beginning Tract Profiling on MWF...'
    Tractometry -i tracking/ -o Tractometry_mwf.csv -e endings_segmentations/ -s ${tr_fld}/mwf.nii.gz --tracking_format tck 

    cd ${base_folder}
    echo "Next subject..."
done
echo "Script complete :D"
# Get the current time when the script finishes
finish_time=$(date "+%Y-%m-%d %H:%M:%S")

echo "Script finished at: $finish_time"