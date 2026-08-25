# Cursor do Dota estourado / lavado — dossiê do caso

**Resolvido em 25/08/2026.** Se o problema voltar, comece pelo `aplicar-conserto.ps1`.

---

## O sintoma

O cursor do mouse dentro do Dota 2 aparece **estourado / lavado / claro demais** no monitor.
Ligar um screen share no Discord **conserta ao vivo, no próprio monitor** — e desligar volta a quebrar.
Acontece com o cursor padrão **e** com cursor cosmético, então não é o desenho de um cursor específico.

## A causa

Bug conhecido do **cursor de hardware** no driver NVIDIA.

O cursor de hardware é desenhado pelo chip de vídeo num plano separado, no último instante antes
de ir pro monitor — ele não passa pelo mesmo pipeline de cor do resto da tela. Nesse driver, esse
plano erra a conversão de cor e o cursor sai estourado.

- Driver na época: `32.0.16.1074` = **NVIDIA 610.74** (fev/2026)
- Thread no fórum da própria NVIDIA: *"Hardware Cursor Incorrectly Brightness / too white"* — em modo **SDR**, com HDR desligado
- Driver **581.80** é relatado como livre do bug
- https://www.nvidia.com/en-us/geforce/forums/geforce-graphics-cards/5/579170/hardware-cursor-incorrectly-brightnesstoo-white-in/

## O conserto

```
HKCU\Control Panel\Mouse  ->  MouseTrails = "-1"
```

Ligar o "rastro do ponteiro" força o Windows a desenhar o cursor **por software** (composto pelo DWM)
em vez de usar o plano de hardware quebrado. O valor `-1` é **fora do range documentado** (0, 2-7),
mas testado e confirmado: força o modo software **sem desenhar cauda visível**.

Confirmação técnica independente do mecanismo — o desenvolvedor do f.lux documentou usar exatamente
esse registro para *"forçar desenho por software do mouse... evita bugs em GPUs que não fazem correção
de cor do cursor"*: https://forum.justgetflux.com/topic/8548/

**Custo: zero processo, zero programa, zero inicialização.** É só configuração; sobrevive a reboot.

### O único preço

Cursor de software é composto **junto com o frame**, então ele atualiza na taxa do monitor (164Hz)
em vez de se mover independente do frame como o cursor de hardware. ~6ms de granularidade a mais.
Imperceptível pra maioria, mas um jogador de Dota pode sentir.

**A única alternativa sem esse preço é o rollback do driver pro 581.80** — mantém cursor de hardware
e corrige a cor. Custo: ficar atrás em versão de driver.

### Valores do MouseTrails

| valor | efeito |
|---|---|
| `0` | desligado — cursor de hardware, **bug volta** |
| `2` a `7` | cursor de software, **com cauda visível** (ruim pro Dota) |
| `-1` | cursor de software, **sem cauda** ← o que usamos |

---

## ❌ Dez hipóteses testadas e MORTAS — não repetir

| # | suspeito | como morreu |
|---|---|---|
| 1 | HDR / Auto HDR | sem chave no registro; medido 8bpc RGB, HDR OFF nos 2 monitores |
| 2 | rampa de gama forçada | `GetDeviceGammaRamp` com Dota aberto → desvio **0** |
| 3 | brilho do jogo (`r_fullscreen_gamma`) | teste inválido (arquivo errado), e não explica "só o cursor" |
| 4 | `SwapEffectUpgradeEnable=0` | sem efeito — é no-op pro Source 2 |
| 5 | `cl_cursor_scale` | sem efeito nem em 32x32 nem acima de 64px |
| 6 | cursor cosmético / loadout shuffle | padrão e cosmético lavam igual |
| 7 | **MPO** (`OverlayTestMode=5` + `OverlayMinFPS=0` + reboot) | sem efeito |
| 8 | janela 1x1 topmost (truque do ForceComposedFlip) | sem efeito |
| 9 | **sessão REAL de captura** (Desktop Duplication) | sem efeito — **mata a teoria de que o Discord conserta forçando composição** |
| 10 | saída de cor 10bpc com desktop em SDR | medido: já estava em **8 bpc** |

A nº 9 é a mais informativa: abrir uma sessão de captura de verdade, igual à do Discord, **não conserta**.
Então o que o Discord faz que conserta ainda é desconhecido. O conserto funciona, a causa do gatilho do
Discord não foi explicada.

---

## Gotchas do Dota (custaram tempo)

1. **Brilho e cursor NÃO moram no `video.txt`.** Moram em `machine_convars.vcfg` (userdata).
   O `video.txt` é espelho que o Dota reescreve **ao sair** — editar com o jogo fechado é ignorado.
2. **A instalação real está no `D:\SteamLibrary`.** A entrada `C:\Program Files (x86)\Steam\...\dota2.exe`
   em `UserGpuPreferences` é lixo de instalação antiga; mexer nela não faz nada.
3. Conta Steam ativa (AutoLogin): `samuelkamus` → userdata **175594820**.

## Gotchas de PowerShell (custaram tempo)

1. `$struct.header.size = X` em struct aninhada escreve numa **cópia** e some.
   Montar o header inteiro e atribuir de uma vez, ou fazer tudo em C#.
2. `0xFFFFFFFF` vira `Int32 -1` e quebra parâmetro `uint`. Usar `[uint32]4294967295`.
3. Backtick de markdown dentro de string com aspas duplas vira escape. Usar here-string `@'...'@`.
4. **Nunca** `Set-Content -Encoding utf8` em config de jogo — grava BOM e corrompe.
   Usar `[IO.File]::WriteAllText($f, $txt, (New-Object System.Text.UTF8Encoding($false)))`
   e conferir os 4 primeiros bytes antes e depois.

---

## Arquivos aqui

| arquivo | o que faz |
|---|---|
| `apply-fix.ps1` | aplica o `MouseTrails=-1` ao vivo (sem reboot, sem fechar o jogo) |
| `revert-fix.ps1` | desliga e devolve o cursor de hardware |
| `diagnose.ps1` | mede tudo: rampa de gama, profundidade de cor, HDR, driver, estado das chaves, e captura o bitmap do cursor |
| `tools/StreamFantasma.exe` | abre sessão real de Desktop Duplication descartando frames — **não resolve este bug**, mas serve pra forçar Composed Flip noutro caso |

## Se o problema voltar

1. Roda `diagnose.ps1` e compara com o que está documentado aqui
2. Se `MouseTrails` estiver diferente de `-1`, roda `apply-fix.ps1`
3. Se estiver `-1` e mesmo assim quebrado, o driver mudou de comportamento — considera o rollback pro 581.80
4. **Não perca tempo com as dez hipóteses da tabela acima**
