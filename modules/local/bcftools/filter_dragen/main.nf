process BCFTOOLS_FILTER_DRAGEN {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bcftools:1.21--h8b25389_1':
        'biocontainers/bcftools:1.21--h8b25389_1' }"

    input:
    tuple val(meta), path(vcf), path(tbi)
    val(filter_type) // 'truth' or 'query'

    output:
    tuple val(meta), path("*.filtered.vcf.gz"), emit: vcf
    tuple val(meta), path("*.filtered.vcf.gz.tbi"), emit: tbi
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    // DRAGEN-specific filters as per Illumina recommendations
    // Truth VCF: Remove ALT="*" records
    // Query VCF: Remove <DUP:TANDEM> symbolic alleles (tandem duplications >1000bp)
    def filter_expr = filter_type == 'truth' ? 'ALT="*"' : 'ALT="<DUP:TANDEM>"'

    """
    bcftools view \\
        -e '${filter_expr}' \\
        ${args} \\
        -Oz \\
        -o ${prefix}.filtered.vcf.gz \\
        ${vcf}

    bcftools index \\
        --tbi \\
        ${prefix}.filtered.vcf.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo | gzip > ${prefix}.filtered.vcf.gz
    touch ${prefix}.filtered.vcf.gz.tbi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """
}
