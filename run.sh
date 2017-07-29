SRA=SRR1686977
ref=onion_rnaseq_ref.fasta
dict=onion_rnaseq_ref.dict

read1=${SRA}_1.fastq.gz
read2=${SRA}_2.fastq.gz

PICARD=/programs/picard/
GATK=/programs/GATK/

python2.7 ncbi_download.py $SRA
/programs/sratoolkit.2.7.0-ubuntu64/bin/fastq-dump --origfmt -I  --split-files --gzip $SRA.sra

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
samtools faidx $ref
java -jar ${PICARD}/picard.jar CreateSequenceDictionary R=$ref  O=$dict

##GATK
java -jar ${GATK}/GenomeAnalysisTK.jar -T HaplotypeCaller -R $ref -I split.bam -dontUseSoftClippedBases -stand_call_conf 20.0 -stand_emit_conf 20.0 -o output.vcf
java -jar ${GATK}/GenomeAnalysisTK.jar -T VariantFiltration -R $ref -V output.vcf -window 35 -cluster 3 -filterName FS -filter "FS > 30.0" -filterName QD -filter "QD < 2.0" -o output.final.vcf
