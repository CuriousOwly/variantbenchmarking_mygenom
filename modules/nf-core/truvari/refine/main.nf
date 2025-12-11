process TRUVARI_REFINE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/truvari:5.3.0--pyhdfd78af_0':
        'biocontainers/truvari:5.3.0--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(summary_json), path(fn_vcf), path(fn_tbi), path(fp_vcf), path(fp_tbi), path(tp_base_vcf), path(tp_base_tbi), path(tp_comp_vcf), path(tp_comp_tbi), path(bench_log)
    tuple val(meta2), path(fasta)
    tuple val(meta3), path(fai)

    output:
    tuple val(meta), path("${prefix}.refined.summary.json"), emit: summary
    tuple val(meta), path("${prefix}.refine.log"), emit: log
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    # Create bench directory structure for truvari refine
    mkdir -p ${prefix}

    # Copy all bench files to the directory
    cp ${summary_json} ${prefix}/summary.json
    cp ${fn_vcf} ${prefix}/fn.vcf.gz
    cp ${fn_tbi} ${prefix}/fn.vcf.gz.tbi
    cp ${fp_vcf} ${prefix}/fp.vcf.gz
    cp ${fp_tbi} ${prefix}/fp.vcf.gz.tbi
    cp ${tp_base_vcf} ${prefix}/tp-base.vcf.gz
    cp ${tp_base_tbi} ${prefix}/tp-base.vcf.gz.tbi
    cp ${tp_comp_vcf} ${prefix}/tp-comp.vcf.gz
    cp ${tp_comp_tbi} ${prefix}/tp-comp.vcf.gz.tbi
    cp ${bench_log} ${prefix}/log.txt

    # Run truvari refine
    truvari refine \\
        --use-original-vcfs \\
        --use-region-coords \\
        --recount \\
        --reference ${fasta} \\
        ${args} \\
        ${prefix} \\
        2>&1 | tee ${prefix}.refine.log

    # Copy refined summary out
    cp ${prefix}/summary.json ${prefix}.refined.summary.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        truvari: \$(echo \$(truvari version 2>&1) | sed 's/^Truvari v//' ))
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.refined.summary.json
    touch ${prefix}.refine.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        truvari: \$(echo \$(truvari version 2>&1) | sed 's/^Truvari v//' ))
    END_VERSIONS
    """
}
