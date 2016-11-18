ref=onion_rnaseq_ref.fasta
dict=onion_rnaseq_ref.dict

read1=SRR4418767_1.fastq.gz
read2=SRR4418767_2.fastq.gz

PICARD=/programs/picard/
GATK=/programs/GATK/

genomeDir=./firstgenomedir
mkdir $genomeDir
STAR --runMode genomeGenerate --genomeDir $genomeDir --genomeFastaFiles $ref  --runThreadN 5

runDir=./firstrundir
mkdir $runDir
cd $runDir
STAR --genomeDir ../$genomeDir --readFilesIn ../$read1 ../$read2  --runThreadN 5 --readFilesCommand zcat
cd ..

genomeDir=./secondgenomedir
mkdir $genomeDir
STAR --runMode genomeGenerate --genomeDir $genomeDir --genomeFastaFiles $ref \
    --sjdbFileChrStartEnd $runDir/SJ.out.tab --sjdbOverhang 75 --runThreadN 5

runDir=./secondrundir
mkdir $runDir
cd $runDir
STAR --genomeDir ../$genomeDir --readFilesIn ../$read1 ../$read2 --runThreadN 5 --readFilesCommand zcat
cd ..

## Picard
java -jar ${PICARD}/picard.jar AddOrReplaceReadGroups I=$runDir/Aligned.out.sam O=rg_added_sorted.bam SO=coordinate RGID=id RGLB=library RGPL=platform RGPU=machine RGSM=sample
java -jar ${PICARD}/picard.jar MarkDuplicates I=rg_added_sorted.bam O=dedupped.bam  CREATE_INDEX=true VALIDATION_STRINGENCY=SILENT M=output.metrics
samtools faidx onion_rnaseq_ref.fasta
java -jar ${PICARD}/picard.jar CreateSequenceDictionary R=$ref  O=$dict

##GATK
java -jar ${GATK}/GenomeAnalysisTK.jar -T HaplotypeCaller -R $ref -I split.bam -dontUseSoftClippedBases -stand_call_conf 20.0 -stand_emit_conf 20.0 -o output.vcf
java -jar ${GATK}/GenomeAnalysisTK.jar -T VariantFiltration -R $ref -V output.vcf -window 35 -cluster 3 -filterName FS -filter "FS > 30.0" -filterName QD -filter "QD < 2.0" -o output.final.vcf