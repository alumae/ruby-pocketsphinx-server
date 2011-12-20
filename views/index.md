Reaalajalise kõnetuvastuse server
================

## Sellest lehest

See leht kirjeldab TTÜ Küberneetika Instituudi [foneetika- kõnetehnoloogia labori](http://www.phon.ioc.ee) reaalajalise kõnetuvastuse serverit ja tema kasutamist. 

## Server

Server on mõeldud lühikeste (max. u 20-sekundiliste) eestikeelsete kõnelõikude tuvastamiseks. 

Serveri lähtekood on BSD litsentsi alusel saadaval [siin](https://github.com/alumae/ruby-pocketsphinx-server). 

Server põhineb ise paljudel vaba tarkvara komponentidel, mille litsentse tuleks serveri kasutamisel arvestada.
Olulisemad tehnoloogiad, mida serveri juures on kasutatud:

* [CMU Sphinx](http://cmusphinx.org) -- server kasutab kõnetuvastuseks Pocketsphinx dekoodrit
* [Wapiti](http://wapiti.limsi.fr) -- kasutatakse liitsõnade rekonstrueerimiseks
* [Sinatra](http://www.sinatrarb.com) --  serveri poolt kasutatav veebiraamistik
* [Grammatical Framework](http://www.grammaticalframework.org) -- kasutakse GF-põhisel tuvastusel

## Rakendused

Hetkel saab serverit kasutada Android-platvormile loodud rakendusega: 

* [Kõnele](http://code.google.com/p/recognizer-intent)
* [Arvutaja](https://github.com/Kaljurand/Arvutaja)

![](http://www.android.com/images/brand/45_avail_market_logo1.png)

Mõlemad rakendused on tasuta ja avatud lähtekoodiga.

## Serveri kasutamine Java rakendustes

Serverit on lihtne kasutada läbi spetsiaalse teegi, mis on tasuta ja koos lähtekoodiga saadaval 
[siin](http://code.google.com/p/net-speech-api).

## Serveri kasutamine muudes rakendustes

Serveri kasutamine on väga lihtne ka "otse", ilma vaheteegita. Järgnevalt demonstreerime, kuidas
serverit kasutada Linuxi käsurealt.

### Näide 1: raw formaadis heli

Lindista mikrofoniga üks lühike lause, kasutades <i>raw</i> formaati, 16 kB, mono kodeeringut (vajuta Ctrl-C, kui oled lõpetanud):

    arecord --format=S16_LE  --file-type raw  --channels 1 --rate 16000 > lause1.raw


Nüüd, saada lause serverisse tuvastamisele:

    curl -X POST --data-binary @lause1.raw \
      -H "Content-Type: audio/x-raw-int; rate=16000" \
      http://bark.phon.ioc.ee/speech-api/v1/recognize?nbest=1


Server genereerib vastuse JSON formaadis:


    {
      "status": 0,
      "hypotheses": [
        {
          "utterance": "see on esimene lause"
        }
      ],
      "id": "4d00ffd9b1a101940bb3ed88c6b6300d"
    }

### Näide 2: ogg formaadis heli

Server tunneb ka formaate flac, ogg, mpeg, wav. Päringu Content-Type väli peaks sel juhul olema
vastavalt audio/x-flac, application/ogg, audio/mpeg või audio/x-wav.

Salvestame ogg formaadis lause (selleks peaks olema installeeritud pakett SoX):

    rec -r 16000 lause2.ogg
    
Saadame serverisse, kasutades PUT päringut:
    
    cat lause2.ogg | curl -T - -H "Content-Type: application/ogg"  "http://bark.phon.ioc.ee/speech-api/v1/recognize?nbest=1"

Väljund:

    {
      "status": 0,
      "hypotheses": [
        {
          "utterance": "see on teine lause"
        }
      ],
      "id": "dfd8ed3a028d1e70e4233f500e21c027"
    }


### Näide 3: mitu tuvastushüpoteesi

Parameeter <code>nbest=1</code> ütles eelmises päringus serverile, et meid huvitab 
ainult üks tulemus. Vaikimisi annab server viis kõige tõenäolisemat tuvastushüpoteesi,
hüpoteesi tõenäosuse järjekorras:

    curl -X POST --data-binary @lause1.raw \
      -H "Content-Type: audio/x-raw-int; rate=16000" \
      http://bark.phon.ioc.ee/speech-api/v1/recognize


Tulemus:

    {
      "status": 0,
      "hypotheses": [
        {
          "utterance": "see on esimene lause"
        },
        {
          "utterance": "see on esimene lause on"
        },
        {
          "utterance": "see on esimene lausa"
        },
        {
          "utterance": "see on mu esimene lause"
        },
        {
          "utterance": "see on esimene laose"
        }
      ],
      "id": "61c78c7271026153b83f39a514dc0c41"
    }

## Korduma kippuvad küsimused

#### Kas server lindistab mu kõnet?

Jah. Üldjuhul neid salvestusi küll keegi ei kuula, aga pisteliselt võidakse
salvestusi kuulata ja käsitsi transkribeerida tuvastuskvaliteedi hindamiseks
ja parandamiseks.

#### Tuvastuskvaliteet on väga halb!

Jah. Parima kvaliteedi saab suu lähedal oleva mikrofoni kasutamisel.
Loodetavasti tulevikus kvaliteet paraneb, kui saame juba serverisse saadetud
salvestusi kasutada mudelite parandamiseks (vt eelmine küsimus).


#### Kas ma võin serverit piiramatult tasuta kasutada?

Mitte päris. Hetkel võib ühelt IP-lt teha tunnis kuni 100 ja päevas kuni 200 tuvastuspäringut.
Tulevikus võivad need limiidid muutuda (see sõltub teenuse populaarsusest ja meie serveripargi
arengust).


#### Mis mõttes see tasuta on?

Tehnoloogia on välja töötatud riikliku programmi "Eesti keeletehnoloogia 2011-2017" raames, seega
on maksumaksja juba selle eest maksnud. Riiklik programm ei pane küll meile
kohustust sellist serverit piiramatult hallata, sellepärast võivad tulevikus
kasutustingimused muutuda, serveri tarkvara aga jääb alatiseks tasuta, kui
ei teki mingeid muid seniarvestamata asjaolusid.

#### OK, aga kas ma võin siis sellise tuvastustarkava enda serverisse installeerida?

Jah. Serveri tarkvara on saadaval [siin](https://github.com/alumae/ruby-pocketsphinx-server),
eesti keele akustilise ja statistilise keelemudeli ning liitsõnade rekonstrueerimismudeli
saamiseks palume kontakteeruda. Mudelid ei ole päris "vabad", s.t. nendele kehtivad teatud
kasutuspiirangud (näiteks ei või neid levitada).

#### Kas iOS (Windows Phone 7, Blackberry, Meego) rakendus ka tuleb?

Hetkel pole plaanis. Samas on server avatud kõikidele rakendustele, seega
võib sellise rakenduse implementeerida keegi kolmas. 

## Kontakt

Tanel Alumäe: [tanel.alumae@phon.ioc.ee](tanel.alumae@phon.ioc.ee)
