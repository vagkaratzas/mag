include { TIARA_TIARA                                                  } from '../../modules/nf-core/tiara/tiara/main'
include { TIARA_CLASSIFY                                               } from '../../modules/local/tiara_classify'
include { DASTOOL_FASTATOCONTIG2BIN as DASTOOL_FASTATOCONTIG2BIN_TIARA } from '../../modules/nf-core/dastool/fastatocontig2bin/main'
include { COMBINE_TSV as TIARA_SUMMARY                                 } from '../../modules/local/combine_tsv'

workflow TIARA {
    take:
    assemblies
    bins
    unbins

    main:
    ch_versions = Channel.empty()

    bins = bins.map { meta, samplebins ->
        def meta_new = meta + [bin: 'bins']
        meta_new.bin = 'bins'
        [meta_new, samplebins]
    }

    unbins = unbins.map { meta, sampleunbins ->
        def meta_new = meta + [bin: 'unbins']
        [meta_new, sampleunbins]
    }

    ch_tiara_input = bins.mix(unbins)

    TIARA_TIARA(assemblies)
    ch_versions = ch_versions.mix(TIARA_TIARA.out.versions.first())

    // Need contig2bin file for each bin group
    DASTOOL_FASTATOCONTIG2BIN_TIARA(ch_tiara_input, 'fa')
    ch_versions = ch_versions.mix(DASTOOL_FASTATOCONTIG2BIN_TIARA.out.versions.first())

    // Need to per-assembly Tiara classifications to their bins
    // Have to remove binner information from the meta map to do this
    ch_contigs_to_bin_tiara = DASTOOL_FASTATOCONTIG2BIN_TIARA.out.fastatocontig2bin
        .combine(ch_tiara_input, by: 0)
        .map { meta, contig2bin, samplebins ->
            def meta_join = meta - meta.subMap('binner', 'bin')
            [meta_join, meta, contig2bin, samplebins]
        }

    ch_tiara_classify_input = ch_contigs_to_bin_tiara
        .combine(TIARA_TIARA.out.classifications, by: 0)
        .map { meta_join, meta, contig2bin, samplebins, classifications ->
            [meta, classifications, contig2bin, samplebins]
        }

    TIARA_CLASSIFY(ch_tiara_classify_input)
    ch_versions = ch_versions.mix(TIARA_CLASSIFY.out.versions.first())

    ch_eukarya_bins = TIARA_CLASSIFY.out.eukarya_bins.map { meta, samplebins ->
        def meta_new = meta + [domain: 'eukarya']
        [meta_new, samplebins]
    }

    ch_prokarya_bins = TIARA_CLASSIFY.out.prokarya_bins.map { meta, samplebins ->
        def meta_new = meta + [domain: 'prokarya']
        [meta_new, samplebins]
    }

    ch_bacteria_bins = TIARA_CLASSIFY.out.bacteria_bins.map { meta, samplebins ->
        def meta_new = meta + [domain: 'bacteria']
        [meta_new, samplebins]
    }

    ch_archaea_bins = TIARA_CLASSIFY.out.archaea_bins.map { meta, samplebins ->
        def meta_new = meta + [domain: 'archaea']
        [meta_new, samplebins]
    }

    ch_organelle_bins = TIARA_CLASSIFY.out.organelle_bins.map { meta, samplebins ->
        def meta_new = meta + [domain: 'organelle']
        [meta_new, samplebins]
    }

    ch_unknown_bins = TIARA_CLASSIFY.out.unknown_bins.map { meta, samplebins ->
        def meta_new = meta + [domain: 'unknown']
        [meta_new, samplebins]
    }

    ch_classified_bins_unbins = ch_eukarya_bins
        .mix(ch_prokarya_bins)
        .mix(ch_bacteria_bins)
        .mix(ch_archaea_bins)
        .mix(ch_organelle_bins)
        .mix(ch_unknown_bins)

    ch_classified_bins = ch_classified_bins_unbins
        .filter { meta, samplebins ->
            meta.bin == "bins"
        }
        .map { meta, samplebins ->
            def meta_new = meta - meta.subMap('bin')
            [meta_new, samplebins]
        }

    ch_classified_unbins = ch_classified_bins_unbins
        .filter { meta, samplebins ->
            meta.bin == "unbins"
        }
        .map { meta, samplebins ->
            def meta_new = meta - meta.subMap('bin')
            [meta_new, samplebins]
        }

    ch_bin_classifications = TIARA_CLASSIFY.out.bin_classifications
        .map { meta, classification ->
            [classification]
        }
        .collect()

    TIARA_SUMMARY(ch_bin_classifications)

    emit:
    classified_bins   = ch_classified_bins
    classified_unbins = ch_classified_unbins
    versions          = ch_versions
}
