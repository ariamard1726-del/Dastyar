# Noql dump

```json
{
 "version": "1.0",
 "truncation": {
  "direction": "Right",
  "max_length": 512,
  "strategy": "LongestFirst",
  "stride": 0
 },
 "padding": {
  "strategy": "BatchLongest",
  "direction": "Right",
  "pad_to_multiple_of": null,
  "pad_id": 0,
  "pad_type_id": 0,
  "pad_token": "[PAD]"
 },
 "added_tokens": [
  {
   "id": 0,
   "content": "[PAD]",
   "single_word": false,
   "lstrip": false,
   "rstrip": false,
   "normalized": false,
   "special": true
  },
  {
   "id": 1,
   "content": "[UNK]",
   "single_word": false,
   "lstrip": false,
   "rstrip": false,
   "normalized": false,
   "special": true
  },
  {
   "id": 2,
   "content": "[CLS]",
   "single_word": false,
   "lstrip": false,
   "rstrip": false,
   "normalized": false,
   "special": true
  },
  {
   "id": 3,
   "content": "[SEP]",
   "single_word": false,
   "lstrip": false,
   "rstrip": false,
   "normalized": false,
   "special": true
  },
  {
   "id": 4,
   "content": "[MASK]",
   "single_word": false,
   "lstrip": false,
   "rstrip": false,
   "normalized": false,
   "special": true
  }
 ],
 "normalizer": {
  "type": "Sequence",
  "normalizers": [
   {
    "type": "Replace",
    "pattern": {
     "Regex": "\\s+"
    },
    "content": " "
   },
   {
    "type": "Strip",
    "strip_left": true,
    "strip_right": true
   }
  ]
 },
 "pre_tokenizer": {
  "type": "Metaspace",
  "replacement": "▁",
  "prepend_scheme": "always",
  "split": true
 },
 "post_processor": {
  "type": "TemplateProcessing",
  "single": [
   {
    "SpecialToken": {
     "id": "[CLS]",
     "type_id": 0
    }
   },
   {
    "Sequence": {
     "id": "A",
     "type_id": 0
    }
   },
   {
    "SpecialToken": {
     "id": "[SEP]",
     "type_id": 0
    }
   }
  ],
  "pair": [
   {
    "SpecialToken": {
     "id": "[CLS]",
     "type_id": 0
    }
   },
   {
    "Sequence": {
     "id": "A",
     "type_id": 0
    }
   },
   {
    "SpecialToken": {
     "id": "[SEP]",
     "type_id": 0
    }
   },
   {
    "Sequence": {
     "id": "B",
     "type_id": 1
    }
   },
   {
    "SpecialToken": {
     "id": "[SEP]",
     "type_id": 1
    }
   }
  ],
  "special_tokens": {
   "[CLS]": {
    "id": "[CLS]",
    "ids": [
     2
    ],
    "tokens": [
     "[CLS]"
    ]
   },
   "[SEP]": {
    "id": "[SEP]",
    "ids": [
     3
    ],
    "tokens": [
     "[SEP]"
    ]
   }
  }
 },
 "decoder": {
  "type": "Sequence",
  "decoders": [
   {
    "type": "Replace",
    "pattern": {
     "String": "▁"
    },
    "content": " "
   },
   {
    "type": "ByteFallback"
   },
   {
    "type": "Fuse"
   },
   {
    "type": "Strip",
    "content": " ",
    "start": 1,
    "stop": 0
   }
  ]
 },
 "model": {
  "type": "Unigram",
  "unk_id": 1,
  "byte_fallback": true
 }
}
```

vocab size 38016; first 12: [['[PAD]', 0.0], ['[UNK]', 0.0], ['[CLS]', 0.0], ['[SEP]', 0.0], ['[MASK]', 0.0], ['\u200c', 0.0], ['<0x00>', 0.0], ['<0x01>', 0.0], ['<0x02>', 0.0], ['<0x03>', 0.0], ['<0x04>', 0.0], ['<0x05>', 0.0]]
min score -16.703271865844727; max piece len 16
pieces containing ▁ not at start: 0
pieces containing ZWNJ: 1

- 'سلام'
  - norm: 'سلام'
  - tokens: ['[CLS]', '▁سلام', '[SEP]']
  - ids: [2, 1946, 3]  types: [0, 0, 0]
- 'می\u200cخواهم طلاق بگیرم'
  - norm: 'می\u200cخواهم طلاق بگیرم'
  - tokens: ['[CLS]', '▁می', '\u200c', 'خواهم', '▁طلاق', '▁بگیرم', '[SEP]']
  - ids: [2, 268, 5, 3058, 2934, 5700, 3]  types: [0, 0, 0, 0, 0, 0, 0]
- 'می خواهم   از همسرم  طلاق بگیرم'
  - norm: 'می خواهم از همسرم طلاق بگیرم'
  - tokens: ['[CLS]', '▁می', '▁خواهم', '▁از', '▁همسرم', '▁طلاق', '▁بگیرم', '[SEP]']
  - ids: [2, 268, 4729, 269, 9569, 2934, 5700, 3]  types: [0, 0, 0, 0, 0, 0, 0, 0]
- '  سلام.  من یک سوال حقوقی دارم '
  - norm: 'سلام. من یک سوال حقوقی دارم'
  - tokens: ['[CLS]', '▁سلام', '.', '▁من', '▁یک', '▁سوال', '▁حقوقی', '▁دارم', '[SEP]']
  - ids: [2, 1946, 264, 327, 285, 1224, 1762, 1121, 3]  types: [0, 0, 0, 0, 0, 0, 0, 0, 0]
- 'کارفرماي من حقوقم را پرداخت نكرده است'
  - norm: 'کارفرماي من حقوقم را پرداخت نكرده است'
  - tokens: ['[CLS]', '▁کارفرما', '<0xD9>', '<0x8A>', '▁من', '▁حقوق', 'م', '▁را', '▁پرداخت', '▁ن', '<0xD9>', '<0x83>', 'رده', '▁است', '[SEP]']
  - ids: [2, 6592, 223, 144, 327, 826, 317, 273, 952, 897, 223, 137, 6463, 274, 3]  types: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
- 'پسرم ۱۶ ساله است'
  - norm: 'پسرم ۱۶ ساله است'
  - tokens: ['[CLS]', '▁پسرم', '▁۱۶', '▁ساله', '▁است', '[SEP]']
  - ids: [2, 12004, 1437, 1745, 274, 3]  types: [0, 0, 0, 0, 0, 0]
- 'ماده 10 قانون کار'
  - norm: 'ماده 10 قانون کار'
  - tokens: ['[CLS]', '▁ماده', '▁', '1', '0', '▁قانون', '▁کار', '[SEP]']
  - ids: [2, 914, 262, 296, 304, 779, 326, 3]  types: [0, 0, 0, 0, 0, 0, 0, 0]
- 'iPhone خریدم 😀 خراب بود'
  - norm: 'iPhone خریدم 😀 خراب بود'
  - tokens: ['[CLS]', '▁iPhone', '▁خریدم', '▁', '<0xF0>', '<0x9F>', '<0x98>', '<0x80>', '▁خراب', '▁بود', '[SEP]']
  - ids: [2, 24004, 18747, 262, 246, 165, 158, 134, 3916, 298, 3]  types: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
- 'مهریه\u200cام ۱۱۰ سکه است، شوهرم می\u200cگوید «ندارم»!'
  - norm: 'مهریه\u200cام ۱۱۰ سکه است، شوهرم می\u200cگوید «ندارم»!'
  - tokens: ['[CLS]', '▁مهریه', '\u200c', 'ام', '▁۱۱۰', '▁سکه', '▁است', '،', '▁شوهرم', '▁می', '\u200c', 'گوید', '▁«', 'ن', 'دارم', '»', '!', '[SEP]']
  - ids: [2, 8068, 5, 510, 8404, 4060, 274, 265, 21886, 268, 5, 831, 309, 455, 10488, 336, 386, 3]  types: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
- 'آیا حق دارد؟'
  - norm: 'آیا حق دارد؟'
  - tokens: ['[CLS]', '▁آیا', '▁حق', '▁دارد', '؟', '[SEP]']
  - ids: [2, 748, 946, 302, 334, 3]  types: [0, 0, 0, 0, 0, 0]
- 'هٔ ۀ ة ئ أ إ آ'
  - norm: 'هٔ ۀ ة ئ أ إ آ'
  - tokens: ['[CLS]', '▁', 'هٔ', '▁', 'ۀ', '▁', '<0xD8>', '<0xA9>', '▁', 'ئ', '▁أ', '▁', '<0xD8>', '<0xA5>', '▁آ', '[SEP]']
  - ids: [2, 262, 4807, 262, 692, 262, 222, 175, 262, 4926, 2799, 262, 222, 171, 2772, 3]  types: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
- 'خانه\u200cام\u200c را'
  - norm: 'خانه\u200cام\u200c را'
  - tokens: ['[CLS]', '▁خانه', '\u200c', 'ام', '\u200c', '▁را', '[SEP]']
  - ids: [2, 662, 5, 510, 5, 273, 3]  types: [0, 0, 0, 0, 0, 0, 0]
- 'a\tb\nc'
  - norm: 'a b c'
  - tokens: ['[CLS]', '▁a', '▁b', '▁c', '[SEP]']
  - ids: [2, 328, 3913, 2778, 3]  types: [0, 0, 0, 0, 0]
- 'قرار\u200cداد'
  - norm: 'قرار\u200cداد'
  - tokens: ['[CLS]', '▁قرار', '\u200c', 'داد', '[SEP]']
  - ids: [2, 312, 5, 1662, 3]  types: [0, 0, 0, 0, 0]
- 'ﻻ ﷲ ﺳﻼﻡ'
  - norm: 'ﻻ ﷲ ﺳﻼﻡ'
  - tokens: ['[CLS]', '▁', '<0xEF>', '<0xBB>', '<0xBB>', '▁', '<0xEF>', '<0xB7>', '<0xB2>', '▁ﺳ', '<0xEF>', '<0xBB>', '<0xBC>', '<0xEF>', '<0xBB>', '<0xA1>', '[SEP]']
  - ids: [2, 262, 245, 193, 193, 262, 245, 189, 184, 17942, 245, 193, 194, 245, 193, 167, 3]  types: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
- ''
  - norm: ''
  - tokens: ['[CLS]', '[SEP]']
  - ids: [2, 3]  types: [0, 0]
- ' '
  - norm: ''
  - tokens: ['[CLS]', '[SEP]']
  - ids: [2, 3]  types: [0, 0]

## weights
- embeddings.LayerNorm.bias: (128,) float32
- embeddings.LayerNorm.weight: (128,) float32
- embeddings.position_embeddings.weight: (512, 128) float32
- embeddings.token_type_embeddings.weight: (2, 128) float32
- embeddings.word_embeddings.weight: (38016, 128) float32
- encoder.albert_layer_groups.0.albert_layers.0.attention.LayerNorm.bias: (768,) float32
- encoder.albert_layer_groups.0.albert_layers.0.attention.LayerNorm.weight: (768,) float32
- encoder.albert_layer_groups.0.albert_layers.0.attention.dense.bias: (768,) float32
- encoder.albert_layer_groups.0.albert_layers.0.attention.dense.weight: (768, 768) float32
- encoder.albert_layer_groups.0.albert_layers.0.attention.key.bias: (768,) float32
- encoder.albert_layer_groups.0.albert_layers.0.attention.key.weight: (768, 768) float32
- encoder.albert_layer_groups.0.albert_layers.0.attention.query.bias: (768,) float32
- encoder.albert_layer_groups.0.albert_layers.0.attention.query.weight: (768, 768) float32
- encoder.albert_layer_groups.0.albert_layers.0.attention.value.bias: (768,) float32
- encoder.albert_layer_groups.0.albert_layers.0.attention.value.weight: (768, 768) float32
- encoder.albert_layer_groups.0.albert_layers.0.ffn.bias: (3072,) float32
- encoder.albert_layer_groups.0.albert_layers.0.ffn.weight: (3072, 768) float32
- encoder.albert_layer_groups.0.albert_layers.0.ffn_output.bias: (768,) float32
- encoder.albert_layer_groups.0.albert_layers.0.ffn_output.weight: (768, 3072) float32
- encoder.albert_layer_groups.0.albert_layers.0.full_layer_layer_norm.bias: (768,) float32
- encoder.albert_layer_groups.0.albert_layers.0.full_layer_layer_norm.weight: (768,) float32
- encoder.embedding_hidden_mapping_in.bias: (768,) float32
- encoder.embedding_hidden_mapping_in.weight: (768, 128) float32
- pooler.bias: (768,) float32
- pooler.weight: (768, 768) float32

## 1_Pooling/config.json
```json
{
    "embedding_dimension": 768,
    "pooling_mode": "mean",
    "include_prompt": true
}
```

## modules.json
```json
[
  {
    "idx": 0,
    "name": "0",
    "path": "",
    "type": "sentence_transformers.models.Transformer"
  },
  {
    "idx": 1,
    "name": "1",
    "path": "1_Pooling",
    "type": "sentence_transformers.models.Pooling"
  },
  {
    "idx": 2,
    "name": "2",
    "path": "2_Normalize",
    "type": "sentence_transformers.models.Normalize"
  }
]
```

## config_sentence_transformers.json
```json
{
  "__version__": {
    "pytorch": "2.14.0+cu130",
    "sentence_transformers": "6.1.0",
    "transformers": "5.17.0"
  },
  "default_prompt_name": null,
  "model_type": "SentenceTransformer",
  "prompts": {
    "document": "",
    "query": ""
  },
  "similarity_fn_name": "cosine"
}
```

## sentence_bert_config.json
```json
{
    "transformer_task": "feature-extraction",
    "modality_config": {
        "text": {
            "method": "forward",
            "method_output_name": "last_hidden_state"
        }
    },
    "module_output_name": "token_embeddings"
}
```
