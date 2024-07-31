#!/bin/bash
##This file is for registrations. I would go through this first. Here our aim is to register MWF to DTI data (so you can overlay them without FSLeyes complaining)
##We will also create a "non-CSF mask", so that whatever we do later on with tract profiling won't involve CSF.
##Note that for your purposes, TVDE/MDD mean DTI and CALIPR means MWI.
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

    # Set up folder locations
    # Most of these folders don't exist yet! Make as needed.
    # TVE/MDD = DTI
    # CALIPR = MWI
    
    base_folder="/data/ubcitm10/awu" # "/home/awu/Documents"
    # script_folder="/home/awu/Documents/data_analysis_scripts"                             # The folder where this script lives, and all subject folders
    #folder_mdd_base="/Users/sharada/Documents/Projects/MDDE/V2/${subject}/MDD"      # MDD was diffusion for another project, ignore
    folder_mdd="/data/ubcitm10/awu/by_patient_all_data/${subject}/DTI/M0"                    # This is where your FA map lives
    folder_mdd_in="/data/ubcitm10/awu/by_patient_all_data/${subject}/DTI/M0"                 # This is where your DTI-B.nii.gz lives
    folder_mwf="/data/ubcitm10/awu/by_patient_all_data/${subject}/MWF/M0"                    # This is MWI folder, has the volumes data
    folder_ants="/data/ubcitm10/awu/by_patient_all_data/${subject}/ants"                     # This is the folder where you will put registered data
    folder_3dt1="/data/ubcitm10/awu/by_patient_all_data/${subject}/Structural/M0"            # This is where 3DT1 originally lives (and FLAIR!)
    folder_flair="/data/ubcitm10/awu/by_patient_all_data/${subject}/Structural/M0/ANTs"  


    # From the MWI data (which has 48 echoes), extract E1 and E24 (1st and 24th volumes) for registration purposes. Whatever warps you create for 
    # one of these images, you can then apply to the MWF map as well.

    ############ Now deal with MWF ############ 
    
    echo "Working on MWF logistics"
    cd ${base_folder}
    mkdir ${folder_ants}
    mkdir ${folder_ants}/MWI

    # Take 1st echo for registration to 3DT1, 24th echo for registration to DTI
    # I think my volumes are already separated? except for 02-CON-005 M12 

    # fslroi ${folder_mwf}/${subject}_CALIPR.nii.gz ${folder_ants}/CALIPR/${subject}_E1.nii.gz 0 1    # MWI folder 
    # fslroi ${folder_mwf}/${subject}_CALIPR.nii.gz ${folder_ants}/CALIPR/${subject}_E24.nii.gz 23 1  # 

    ##Extract the brain from E1. This is important (and can take some time)!! Extracted brain allows a version with no skull to be
    ##used in registrations.
    echo "Beginning brain extraction on MWI E1..."
    antsBrainExtraction.sh -d 3 -a ${folder_mwf}/vol0001.nii.gz -e ${base_folder}/NKHI_Template/T_template.nii.gz -m ${base_folder}/NKHI_Template/T_template_BrainCerebellumProbabilityMask.nii.gz -c 3x1x2x3 -o ${folder_ants}/MWI/
    ##Brain extraction should create a BrainExtractionMask and BrainExtractionBrain file.
    echo "Done brian extraction on E1"

    #Multiply MWF map, E1, E28 by brain mask so that you are left with just brain, no outside bits.
    echo "Multiplying MWF map by brain mask..."
    fslmaths ${folder_mwf}/${subject}_METRICS_MWF.nii.gz -mul ${folder_ants}/MWI/BrainExtractionMask.nii.gz ${folder_ants}/MWI/MWF_brain.nii.gz
    fslmaths ${folder_mwf}/vol0024.nii.gz -mul ${folder_ants}/MWI/BrainExtractionMask.nii.gz ${folder_ants}/MWI/${subject}_E24.nii.gz
    fslmaths ${folder_mwf}/vol0001.nii.gz -mul ${folder_ants}/MWI/BrainExtractionMask.nii.gz ${folder_ants}/MWI/${subject}_E1.nii.gz
    echo "Done multiplying"

    ###################### Now some bits that are not really necessary, but there if you want it ######################

    #Extract 3DT1 brain. This takes a little time. Make the directory for it first. 
    #Brain extraction is often necessary for better registrations further down the line, and for creating a CSF mask.
    #This relies on there being a "template" brain extraction
    # NOTE: brain extraction already done for 3DT1 data
    mkdir ${folder_ants}/3DT1
    # antsBrainExtraction.sh -d 3 -a ${subject}/NIFTI/3DT1.nii.gz -e /Users/sharada/Documents/ANTs/NKI_Template/T_template.nii.gz -m /Users/sharada/Documents/ANTs/NKI_Template/T_template_BrainCerebellumProbabilityMask.nii.gz -o ${folder_ants}/3DT1/
    ##If there is FLAIR, do this for FLAIR images as well.

    ######################################################################################################################################################
    # ##########3DT1 to MNI-- not strictly necessary here.
    # #Let's try registering the T1 to the MNI 1mm template.
    # #The warped T1 template is in Warped.nii.gz, view BrainExtractionBrain and Warped together to see that they fit.
    # ##The warp to use forever on is 0GenericAffine.mat
    # mv ${folder_ants}/3DT1/BrainExtractionBrain.nii.gz ${folder_ants}/3DT1/3DT1.nii.gz 
    # antsRegistrationSyNQuick.sh -d 3 -f ${folder_ants}/3DT1/3DT1.nii.gz -m /usr/local/fsl/data/standard/MNI152_T1_1mm_brain.nii.gz -o ${folder_ants}/3DT1/ -n 6
    ##################################################################################################################################################################################################################

    ############ Set up Diffusion stuff ############

    #Make directories to store MDD data in ants folder
    mkdir ${folder_ants}/DTI
    ## Extract the first volume from DTI-B.nii.gz. This is the b=0 volume that will get used for image registration.
    ## The other volumes in DTI-B.nii.gz will get used in tractography.
    # volumes already extracted? 
    # fslroi ${folder_mdd}/FWF_mc.nii.gz ${folder_ants}/DTI/FWF_mc_b0.nii.gz 0 1
    #Multiply that b=0 image with a brain extraction mask (hifi_nodif_mask?) to keep just the brain part, no outsides.
    
    # first extract brain to get brain extraction brain and brain extraction mask for DTI
    echo "Beginning brain extraction on DTI (first echo)..."
    antsBrainExtraction.sh -d 3 -a ${folder_mdd}/vol0001.nii.gz -e ${base_folder}/NKHI_Template/T_template.nii.gz -m ${base_folder}/NKHI_Template/T_template_BrainCerebellumProbabilityMask.nii.gz -c 3x1x2x3 -o ${folder_ants}/DTI/
    echo "Done brain extraction"
    ##Brain extraction should create a BrainExtractionMask and BrainExtractionBrain file.
    fslmaths ${folder_mdd}/vol0001.nii.gz -mul ${folder_ants}/DTI/BrainExtractionMask.nii.gz ${folder_ants}/DTI/${subject}_E1.nii.gz


    ####################### Register DTI->3DT1. This is necessary for stuff further down. #######
    echo "Registering DTI and 3DT1..."
    mkdir ${folder_ants}/DTI_3DT1
    antsRegistrationSyN.sh -d 3 -f ${folder_ants}/DTI/${subject}_E1.nii.gz -m ${folder_3dt1}/ANTs/BrainExtractionBrain.nii.gz -r 1 -g 0.05 -o ${folder_ants}/DTI_3DT1/
    ##This will generate: 1Warp, 1InverseWarp, Warped, InverseWarped, 0GenericAffine files. As a sanity check, can overlay
    ##Can play with antsRegistrationSyN params to make this better, or use FSL's epi_reg tool (example usage further down)
    echo "Done registration"
    ##################################################################################################################################################################################################################
    # ###This step isn't strictly necessary for tract profiling but in case you want it... registering MWI to 3DT1
    # mkdir ${folder_ants}/CALIPR_3DT1
    # antsRegistrationSyNQuick.sh -d 3 -f ${folder_ants}/CALIPR/${subject}_E1.nii.gz -m ${folder_ants}/3DT1/3DT1.nii.gz -o ${folder_ants}/CALIPR_3DT1/ -n 8 
    ##################################################################################################################################################################################################################


    ##### IMPORTANT: register MWI to DTI space. You want both MWF and FA maps in the same resolution/coordinate space
    #### to do tract profiling, so that you are definitely profiling the same areas. ##############
    ##Create folder
    mkdir ${folder_ants}/MWI_DTI
    echo "Registering MWI to DTI..."
    ##Run an antsRegistrationSyN command to warp E24 of the MWI data (which you extracted from the 48 echoes earlier)
    antsRegistrationSyN.sh -d 3 -m ${folder_ants}/MWI/${subject}_E24.nii.gz -f ${folder_ants}/DTI/${subject}_E1.nii.gz -o ${folder_ants}/MWI_DTI/ -t a -r 5
    ##This will generate: 1Warp, 1InverseWarp, Warped, InverseWarped, 0GenericAffine files. As a sanity check, can overlay
    ##Warped.nii.gz and DTI's b=0 image and see if they match. Suggest playing with params of antsRegistrationSyN.sh to make it better.
    echo "Done registration"
    echo "Warping MWF to DTI space..."
    ##Apply the warp you just generated to MWF, to make it be in DTI coordinate system/resolution.
    antsApplyTransforms -d 3 -e 0 -i ${folder_ants}/MWI/MWF_brain.nii.gz -r ${folder_ants}/DTI/${subject}_E1.nii.gz -t ${folder_ants}/MWI_DTI/0GenericAffine.mat -o ${folder_ants}/MWI_DTI/MWF.nii.gz
    echo "Done warping"
    ############################## An alternative, in case the ANTs way did not work out well, is to use FSL's epi_reg tool which often works better. ##############################
    ###We are aiming to do the same thing, but note here that the warp is from Diffusion->MWI not MWI->Diffusion.
    # epi_reg --epi=${folder_ants}/MDD/FWF_mc_b0 --t1=${folder_ants}/CALIPR/${subject}_E1 --t1brain=${folder_ants}/CALIPR/${subject}_E1_brain --out=${folder_ants}/CALIPR_MDD/b0_to_E1
    ##This is an example of applying the Diffusion->MWI warp to the FA map to make it match MWI dimensions. This isn't what we're after.
    # flirt -in ${folder_mdd}/qti/qti_fa.nii.gz -ref ${folder_ants}/CALIPR/${subject}_E1 -out ${folder_ants}/CALIPR_MDD/fa -init ${folder_ants}/CALIPR_MDD/b0_to_E1.mat -applyxfm

    # ##We need to INVERT the warp to do MWI->Diffusion space
    # convert_xfm -omat ${folder_ants}/CALIPR_MDD/E1_to_b0.mat -inverse ${folder_ants}/CALIPR_MDD/b0_to_E1.mat
    # ##Apply this inverse to MWF to make MWF in Diffusion space.
    # flirt -in ${folder_ants}/CALIPR/MWF_brain.nii.gz -ref ${folder_ants}/MDD/FWF_mc_b0 -out ${folder_ants}/CALIPR_MDD/mwf -init ${folder_ants}/CALIPR_MDD/E1_to_b0.mat -applyxfm
    ####################################################################################################################################################################################

    ############## Make a CSF mask. A CSF mask is necessary so that when you do the profiling, you avoid CSF (which will make the profiles weird). ###############
    #Get a WM/GM/CSF mask in 3DT1 space
    echo "Beginning CSF Mask creation..."
    Atropos -d 3 -a ${folder_3dt1}/ANTs/BrainExtractionBrain.nii.gz -i KMeans[3] -x ${folder_3dt1}/ANTs/BrainExtractionMask.nii.gz -o ${folder_ants}/3DT1/segmented.nii.gz

    ###Extract just the CSF portion of it, which is labeled "1".
    echo "Extracting CSF from mask"
    fslmaths ${folder_ants}/3DT1/segmented.nii.gz -thr 1 -uthr 1 -bin ${folder_ants}/3DT1/csf_mask.nii.gz

    # apply the mask to DTI data
    echo "Applying mask to data"
    antsApplyTransforms -d 3 -e 0 -i ${folder_ants}/3DT1/csf_mask.nii.gz -r ${folder_ants}/DTI/${subject}_E1.nii.gz -t ${folder_ants}/DTI_3DT1/1Warp.nii.gz -t ${folder_ants}/DTI_3DT1/0GenericAffine.mat -o ${folder_ants}/DTI/csf_mask.nii.gz
    fslmaths ${folder_ants}/DTI/csf_mask.nii.gz -thr 0.99 -bin ${folder_ants}/DTI/csf_mask.nii.gz

    #Invert it so non-CSF is 1 and CSF is 0, for use in profiling (basically you will be multiplying FA/MWF by this non-CSF mask to keep just non-CSF areas).
    fslmaths ${folder_ants}/DTI/csf_mask.nii.gz -mul -1 -add 1 ${folder_ants}/DTI/csf_mask.nii.gz
    ##Alternatively you can just add up the WM+GM masks and warp that over too.
    echo "Subject complete"

    ########################################################################################################
    echo "Working on FLAIR logistics"
    
    cd ${base_folder}

    ##Extract the brain from E1. This is important (and can take some time)!! Extracted brain allows a version with no skull to be
    ##used in registrations.
    echo "Beginning brain extraction on MWI E1..."
    mkdir ${folder_ants}/FLAIR_DTI
    antsBrainExtraction.sh -d 3 -a ${folder_flair}/normalizedFLAIR.nii.gz -e ${base_folder}/NKHI_Template/T_template.nii.gz -m ${base_folder}/NKHI_Template/T_template_BrainCerebellumProbabilityMask.nii.gz -c 3x1x2x3 -o ${folder_ants}/FLAIR_DTI/
    ##Brain extraction should create a BrainExtractionMask and BrainExtractionBrain file.
    echo "Done brian extraction on E1"

    #Multiply MWF map, E1, E28 by brain mask so that you are left with just brain, no outside bits.
    echo "Multiplying MWF map by brain mask..."
    fslmaths ${folder_flair}/normalizedFLAIR.nii.gz -mul ${folder_ants}/FLAIR_DTI/BrainExtractionMask.nii.gz ${folder_ants}/FLAIR_DTI/FLAIR_brain.nii.gz

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