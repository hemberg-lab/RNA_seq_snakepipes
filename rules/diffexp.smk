def get_strandness(units):
    if "strandedness" in units.columns:
        return units["strandedness"].tolist()
    else:
        strand_list=["none"]
        return strand_list*units.shape[0]

comparison_names = config["diffexp"]["contrasts"].keys()
    
comparison_samples = []

for name in comparison_names:
    comparison_samples += list(conditions.loc[config["diffexp"]["contrasts"][name][0], "sample"])
    comparison_samples += list(conditions.loc[config["diffexp"]["contrasts"][name][1], "sample"])
    

    
rule count_matrix:
    input:
        set(expand("featureCounts/{sample}.gene_count.txt", sample=comparison_samples))
    output:
        "counts/all.tsv"
    shell:
        "python scripts/get_count_matrix.py {input} > {output}"
        #'''sed '1d' {input} | awk 'OFS="\t" {{$2=$3=$4=$5=$6=""; print $0}}' | sed 's/hisat2\///g' | sed 's/.sorted.bam//g' | sed 's/Geneid/gene/g' > {output}'''   

def get_deseq2_threads(wildcards=None):
    # https://twitter.com/mikelove/status/918770188568363008
    few_coeffs = False if wildcards is None else len(get_contrast(wildcards)) < 10
    return 1 if len(samples) < 100 or few_coeffs else 6


rule deseq2_init:
    input:
        counts="counts/all.tsv"
    output:
        "deseq2/all.rds"
    params:
        samples=config["samples"]
    conda:
        "../envs/deseq2.yaml"
    log:
        "logs/deseq2/init.log"
    threads: get_deseq2_threads()
    script:
        "../scripts/deseq2-init.R"


#rule pca:
#    input:
#        "deseq2/all.rds"
#    output:
#        report("results/pca.svg", "../report/pca.rst")
#    params:
#        pca_labels=config["pca"]["labels"]
#    conda:
#        "../envs/deseq2.yaml"
#    log:
#        "logs/pca.log"
#    script:
#        "../scripts/plot-pca.R"


def get_contrast(wildcards):
    return config["diffexp"]["contrasts"][wildcards.contrast]


rule deseq2:
    input:
        "deseq2/all.rds"
    output:
        table=report("results/diffexp/{contrast}.diffexp.tsv", "../report/diffexp.rst"),
        ma_plot=report("results/diffexp/{contrast}.ma-plot.svg", "../report/ma.rst"),
    params:
        contrast=get_contrast
    conda:
        "../envs/deseq2.yaml"
    log:
        "logs/deseq2/{contrast}.diffexp.log"
#    threads: get_deseq2_threads
    threads: 1
    script:
        "../scripts/deseq2.R"
