(*****************************************************************************

  Liquidsoap, a programmable audio stream generator.
  Copyright 2003-2013 Savonet team

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details, fully stated in the COPYING
  file at the root of the liquidsoap distribution.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

*****************************************************************************)

(** Resampling module *)

(** TODO: video *)

(** The returned length (int) is in audio samples *)
type audio_converter =
    ?audio_src_rate:float ->
    Frame.audio_t array -> Frame.audio_t array*int

let create_audio () =
  let audio_converters = Hashtbl.create 2 in
  let audio_dst_rate =
    float (Lazy.force Frame.audio_rate)
  in
  (fun ?audio_src_rate audio_buf ->
    let process_audio audio_src_rate =
        (** Create new converters if needed,
            * remove unused converters *)
      let new_audio_chans = Array.length audio_buf in
      let old_audio_chans = Hashtbl.length audio_converters in
      if old_audio_chans < new_audio_chans then
        for i = old_audio_chans to new_audio_chans - 1 do
          Hashtbl.add audio_converters i (Audio_converter.Samplerate.create 1)
        done ;
      if new_audio_chans < old_audio_chans then
        for i = new_audio_chans to new_audio_chans - 1 do
          Hashtbl.remove audio_converters i
        done ;
      let resample_chan n buf =
        let resampler = Hashtbl.find audio_converters n in
        let ret =
          Audio_converter.Samplerate.resample
            resampler (audio_dst_rate /. audio_src_rate)
            [|buf|] 0 (Array.length buf)
        in
        ret.(0)
      in
      let ret = Array.mapi resample_chan audio_buf in
      ret,Array.length ret.(0)
    in
    let audio_rate =
      match audio_src_rate with
        | Some rate -> rate
        | None -> audio_dst_rate
    in
    process_audio audio_rate)

(** The returned length (int) is in audio samples *)
type wav_converter =
    audio_src_rate:float ->
    string -> Frame.audio_t array * int

let create_from_wav ~channels ~samplesize =
  let audio_dst_rate = float (Lazy.force Frame.audio_rate) in
  let sample_bytes = samplesize / 8 in
  let samplerate_converter = Audio_converter.Samplerate.create channels in
  (fun ~audio_src_rate src ->
    let ratio = audio_dst_rate /. audio_src_rate in
    let len = (String.length src) / (sample_bytes*channels) in
    let dst = Array.init channels (fun _ -> Array.make len 0.) in
    let to_audio =
      match samplesize with
      | 8 -> Audio.U8.to_audio
      | 16 -> Audio.S16LE.to_audio
      | _ -> failwith "unsuported sample size"
    in
    to_audio src 0 dst 0 len;
    let dst =
      Audio_converter.Samplerate.resample
        samplerate_converter
        ratio
        dst 0 len
    in
    let dst_len = Array.length dst.(0) in
    dst, dst_len)
