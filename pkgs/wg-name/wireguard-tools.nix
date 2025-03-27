{ bash, wg-name, wireguard-tools }:
wireguard-tools.overrideAttrs (p: {
  pname = "${p.pname}-name";
  buildInputs = p.buildInputs ++ [ wg-name ];
  postFixup =
    ''
      mv "$out/bin/wg" "$out/bin/wg-original"

      ####
      cat > $out/bin/wg <<EOF
      #!${bash}/bin/bash
      excludeWord=( interfaces -h --help )

      if [[ "\$1" == "show" ]]; then
        ################
        # dont run on
        # wg show interfaces
        # wg show (.+) (.+)
        if [[ " \''${excludeWord[*]} " =~ " \$2 " ]] || [[ "\$3" != "" ]]; then
          $out/bin/wg-original \''${@:1}
          exit 0
        fi
        ################

        PATH=$out/bin PROGRAM="wg-original" ${wg-name}/bin/wg-name \''${@:2}
      else
        $out/bin/wg-original \''${@:1}
      fi
      EOF
      ####

      chmod +x "$out/bin/wg"
    '';
})
