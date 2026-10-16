# Chinese wake-word model

Upstream: k2-fsa / sherpa-onnx, `sherpa-onnx-kws-zipformer-wenetspeech-3.3M-2024-01-01`.

Source archive:
https://github.com/k2-fsa/sherpa-onnx/releases/download/kws-models/sherpa-onnx-kws-zipformer-wenetspeech-3.3M-2024-01-01.tar.bz2

The bundled encoder, decoder, and joiner are the upstream `epoch-12-avg-2-chunk-16-left-64.int8.onnx` files, renamed for the app. `tokens.txt` is unchanged. See `MODEL_README.md` for the upstream model description and Apache-2.0 license declaration, and `LICENSE` for the license text.

`keywords.txt` is the app's custom keyword list, using the model's partial-pinyin tokens. Both the neutral and third-tone pronunciations of 朵 map to the wake word 小耳朵. Change thresholds only after evaluating recordings from the intended devices and speaking environments.

Model documentation: https://k2-fsa.github.io/sherpa/onnx/kws/index.html
