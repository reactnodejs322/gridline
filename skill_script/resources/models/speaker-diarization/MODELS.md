# Speaker diarization models

## Segmentation

- Source: [pyannote/segmentation-3.0](https://huggingface.co/pyannote/segmentation-3.0), converted and distributed in [sherpa-onnx-pyannote-segmentation-3-0](https://github.com/k2-fsa/sherpa-onnx/releases/tag/speaker-segmentation-models)
- File: `segmentation/model.onnx`
- License: MIT. The upstream model asks users to accept its access conditions; this converted copy was downloaded from the sherpa-onnx public release. It is run locally and does not require a Hugging Face account.

## Speaker embeddings

- Source: [3D-Speaker](https://github.com/alibaba-damo-academy/3D-Speaker), distributed in sherpa-onnx's speaker-recognition model release
- File: `speaker-embedding/model.onnx`
- License: Apache-2.0. See `speaker-embedding/LICENSE`.

## Runtime

The ONNX models run through `sherpa-onnx==1.13.8`, installed from `skill_script/audio_to_text/requirements.txt`. Keep both model directories together when packaging Gridline; the script resolves both paths from `skill_script/resources/models/`.

The script uses a 0.25 segmentation window shift, four CPU threads, and a 0.9 clustering threshold. A larger threshold favors fewer speaker clusters; it was checked against the current two-speaker Desktop recording.
