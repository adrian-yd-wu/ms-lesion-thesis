#!/bin/bash
##This file is for FLAIR registrations. 

echo "Beginning Image Registration..."
# Set up a list of people

declare -a subjectList=(
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


# Loop through each subject and do the things.
# assumes M0 month
for subject in "${subjectList[@]}"; do
    echo "The current subject is: " ${subject}
    
    base_folder="/data/ubcitm10/awu" # "/home/awu/Documents"
    folder_ants="/data/ubcitm10/awu/by_patient_all_data/${subject}/ants" # This is the folder where you will put registered data
    folder_flair="/data/ubcitm10/awu/by_patient_all_data/${subject}/Structural/M0/ANTs"
    folder_M0="/data/ubcitm10/awu/by_patient_all_data/${subject}/Structural/M0"
    
    echo "Working on FLAIR logistics"
    cd ${base_folder}

    ##Extract the brain from E1. This is important (and can take some time)!! Extracted brain allows a version with no skull to be
    ##used in registrations.
    echo "Beginning brain extraction on MWI E1..."
    mkdir ${folder_ants}/FLAIR_DTI
    antsBrainExtraction.sh -d 3 -a ${folder_M0}/FLAIR-B.nii.gz -e ${base_folder}/NKHI_Template/T_template.nii.gz -m ${base_folder}/NKHI_Template/T_template_BrainCerebellumProbabilityMask.nii.gz -c 3x1x2x3 -o ${folder_ants}/FLAIR_DTI/
    ##Brain extraction should create a BrainExtractionMask and BrainExtractionBrain file.
    echo "Done brian extraction on E1"

    #Multiply MWF map, E1, E28 by brain mask so that you are left with just brain, no outside bits.
    echo "Multiplying MWF map by brain mask..."
    fslmaths ${folder_M0}/FLAIR-B.nii.gz -mul ${folder_ants}/FLAIR_DTI/BrainExtractionMask.nii.gz ${folder_ants}/FLAIR_DTI/FLAIR_brain.nii.gz

    echo "Done multiplying"
    echo "Registering FLAIR to DTI..."

    ##Run an antsRegistrationSyN command to warp E24 of the MWI data (which you extracted from the 48 echoes earlier)
    antsRegistrationSyN.sh -d 3 -m ${folder_ants}/FLAIR_DTI/FLAIR_brain.nii.gz -f ${folder_ants}/DTI/${subject}_E1.nii.gz -o ${folder_ants}/FLAIR_DTI/ -t a -r 5
    ##This will generate: 1Warp, 1InverseWarp, Warped, InverseWarped, 0GenericAffine files. As a sanity check, can overlay

    echo "Done registration"
    echo "Warping MWF to DTI space..."
    ##Apply the warp you just generated to MWF, to make it be in DTI coordinate system/resolution.
    antsApplyTransforms -d 3 -e 0 -i ${folder_ants}/FLAIR_DTI/FLAIR_brain.nii.gz -r ${folder_ants}/DTI/${subject}_E1.nii.gz -t ${folder_ants}/FLAIR_DTI/0GenericAffine.mat -o ${folder_ants}/FLAIR_DTI/FLAIR.nii.gz
    echo "Done warping"
    echo "Subject complete"
done
echo "Script complete"