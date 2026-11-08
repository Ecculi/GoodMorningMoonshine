# GoodMorningMoonshine – suunnitteludokumentti

Elävä dokumentti pelin suunnittelupäätöksistä. Päivitetään sitä mukaa, kun ideat tarkentuvat.

## Yleiskuva

GoodMorningMoonshine on Godot 4:llä tehtävä huumoripitoinen roguelike-henkinen toimintapeli. Inspiraationa on suomalaisen 1980-luvun roguelike-pelin lajityyppi ja mekaniikat, mutta peli on oma: hahmot, esineet, paikat, tarina ja huumori keksitään itse.

**Perusidea:** pelihahmo herää krapulassa ja huomaa hukanneensa tavaroitaan. Hänen pitää lähteä etsimään niitä kaupungilta, selvitä hengissä ja löytää takaisin kotiin.

**Peli on nopeatempoinen.** Mekaniikat, joissa vain odotetaan tai istutaan paikallaan, jätetään pois.

**Pelissä ei ole tupakkaa lainkaan.**

## Kuvakulma ja grafiikka

- **Näytön koko ja kuvasuhde:** peli on suunniteltu 16:9-näytölle (1280×720), eikä kuva veny koskaan. Kapeammalla näytöllä (4:3, puhelin vaakasuunnassa) kadun leveys säilyy, ja näkymä laajenee ylös ja alas; leveämmällä näkyy sivuille enemmän, mutta kamera zoomaa samalla sisään, jottei hahmo kutistu (rajana se, että molemmat jalkakäytävät näkyvät); yli noin 2,6:1 leveällä näytöllä sivuille tulee mustat reunat. Käyttöliittymä on ankkuroitu reunoihin ja keskelle. Puhelin pystyasennossa: ruudulle tulee kääntyvän puhelimen kuva ja "Käännä puhelin vaakaan".

- **Grafiikka toteutetaan tilt-shift-tekniikalla**, jolloin kaupunki näyttää pienoismallilta.
- Peli tehdään **3D:nä**, koska tilt-shift syntyy siinä luontevimmin kameran syväterävyydellä (ylä- ja alareuna sumenevat).
- **Terävä alue seuraa pelaajaa pystysuunnassa.** Kun hahmo liikkuu kadun syvyyssuunnassa ylös tai alas, tarkennuskaista siirtyy hänen mukanaan, joten hahmo on aina terävänä.
- Kuvakulma on viisto sivukuva (beat 'em up / belt scroller -tyyli).
- Pelaaja etenee pääasiassa sivusuunnassa, mutta voi liikkua myös ylös ja alas kadun syvyyssuunnassa.

## Ääni ja musiikki

- **Kaupungin äänet:** lokit, liikenne ja ihmisten puheensorina.
- **Hahmon ääntelyt:** ähkimistä, hikkaa ja mahan kurinaa.
- **Hiljainen taustamusiikki** soi koko ajan, ja se **horjuu humalatilan mukaan**.
- Sisätiloissa soi paikan oma musiikki, esimerkiksi baarissa ja kauppakeskuksessa.

## Ajan kulku

- Peli on reaaliaikainen, mutta **aika etenee vain, kun pelaaja liikkuu tai tekee jotain**. Muuten peli on kuin pausella.
- Erillistä odota-toimintoa ei ole. Paikallaan seistessä ei tapahdu mitään, eikä hahmo esimerkiksi lämpene.
- Liikkuminen kuluttaa aina ruokaa, eli nälkä kasvaa.
- Pelaaja voi kävellä ja **juosta**.

## Kartta ja kaupungit

- Tasot ovat katuja. Näkymä vierii jonkin verran vasemmalle ja oikealle.
- **Yksi pelinäkymä on yksi kortteli**, eli kadun pätkä kahden risteyksen välillä. Risteykset ovat näkymän reunoilla.
  - Risteyksestä jatketaan suoraan samaa katua seuraavaan kortteliin (näkymä vaihtuu) tai käännytään ylös tai alas poikkikadulle (näyttö vaihtuu ja tulee uusi katu).
  - Lyhyet näkymät ovat kevyitä ladata myös mobiilissa ja selaimessa, ja jokaisella korttelilla voi olla oma tunnelmansa.
- **Kadun vaihtuminen:** kun hahmo kävelee näytön vasemmasta tai oikeasta reunasta kokonaan ulos, näkymä vaihtuu heti seuraavaan kortteliin, ja hahmo kävelee sisään toisen reunan takaa.
- **Korttelin ylittää noin 5 sekunnissa**, jos juoksee koko ajan. Kävellen siihen menee kauemmin.
- **Tavarat ovat lähellä kotia:** koko keskusta on käytössä, mutta koti ja hukatut tavarat arvotaan joka päivä muutaman korttelin säteelle toisistaan. **Säde kasvaa päivä päivältä**, mikä on yksi tapa, jolla peli vaikeutuu.
- Jokainen peli sijoittuu johonkin kaupunkiin. Kaupungin kartta on aina sama, mutta **kodin sijainti vaihtuu joka pelissä**, mikä lisää uudelleenpelattavuutta.
- Kun pelaaja kuolee ja aloittaa uuden pelin, kaupunki ja kodin sijainti vaihtuvat.
- **Aluksi toteutetaan vain Oulu.**
- **Asiat eivät ole joka päivä samassa paikassa.** Kartta pysyy samana, mutta tavarat, ruoka, juomat, hahmot ja palvelut (esim. mistä saa kahvia) arvotaan joka päivä uudelleen. Eilen toimiva paikka ei välttämättä toimi tänään.
  - **Rakennukset ovat aina samoilla paikoilla**, koska ne ovat osa Oulun karttaa. Joka päivä arvotaan, **mitkä ovat auki ja mitä niissä on tarjolla** (esim. kioski voi olla kiinni tai baarissa eri portsari).

### Kaupungit

- Pelissä on useita kaupunkeja. **Uusi peli arpoo kaupungin**, ja yksi peli pelataan **samassa kaupungissa kuolemaan asti**. Pelin alussa ruudun keskelle tulee kaupungin nimi isolla ("RAAHE") ja alle "Selviä tässä kaupungissa niin pitkään kuin pystyt"; teksti häipyy, kun hahmo lähtee liikkeelle. Versionumero näkyy samaan aikaan pienellä ruudun alareunassa.
- Kaupungit ovat `scripts/city_map.gd`-tiedoston `CITIES`-listassa: kadut kahtena suuntana, kameran ilmansuunnat, meri, aloituspaikka, poliisiasema ja mahdollinen kävelykatu. Uuden kaupungin lisääminen on yksi uusi tietue.
- **Raahe:** pohjois–eteläsuuntaiset kadut lännestä itään Rantakatu, Kauppakatu, Kirkkokatu, Reiponkatu ja Palokunnankatu; länsi–itäsuuntaiset pohjoisesta etelään Kirkkolahdenkatu, Pitkänkarinkatu, Saaristokatu, Cortenkatu, Brahenkatu, Koulukatu ja Sovionkatu. Meri (Kirkkolahti) on pohjoisessa. Poliisiasema on Brahenkadulla Kirkkokadun ja Reiponkadun välissä. Osittaiset kadut (Ämmänkatu, Nahkurinkuja) puuttuvat vielä (issue #39).

### Oulu

- Alue on **Oulun keskustan ruutukaava**: noin kauppatorin ja rannan (luoteessa) sekä rautatieaseman (idässä) välinen alue, etelässä suunnilleen Sepänkadulle asti.
- Kadut muodostavat kaksi ristikkäistä sarjaa (9 × 7 katua), joten jokaisessa risteyksessä käännytään 90 astetta:
  - **Lounas–koillinen** (luoteesta kaakkoon, tarkistettu kartasta): Rantakatu, Aleksanterinkatu, Torikatu, Kirkkokatu, Isokatu, Uusikatu, Mäkelininkatu, Koulukatu, Rautatienkatu
  - Kanava puistoineen (Otto Karhin puisto, Vaaranpuisto, Lyötynpuisto) kulkee Uusikadun ja Mäkelininkadun välissä. Vaarankatu on vain lyhyt katu kanavan varressa (ei vielä pelissä).
  - **Luode–kaakko** (koillisesta lounaaseen, tarkistettu kartasta): Asemakatu, Hallituskatu, Pakkahuoneenkatu, Kauppurienkatu (Rotuaari), Saaristonkatu, Albertinkatu, Sepänkatu
  - Vain idässä, Uusikadun itäpuolella: Kajaaninkatu, Linnankatu ja Heikinkatu (ei vielä pelissä)
  - **Ojakatu** on Hallituskadun ja kanavan välissä, vain Aleksanterinkadun ja Torikadun välillä. Asemakatu alkaa vasta Torikadulta; sen länsipuolella on kanava ja Madetojan puisto (ei vielä pelissä).
  - Pelin ruudukko olettaa toistaiseksi, että jokainen katu kulkee koko alueen läpi. Osittaiset kadut, puistot ja kanava vaativat myöhemmin tuen puuttuville kortteleille.
- **Kuvakulma kaduilla:** lounas–koillinen-kaduilla kamera katsoo luoteeseen (oikealle on koilliseen), luode–kaakko-kaduilla koilliseen (oikealle on kaakkoon). Risteyksessä ylös tarkoittaa poispäin kamerasta ja alas kohti kameraa. Siksi aurinko ja varjot kääntyvät kadun mukana.
- **Katukyltit risteyksissä:** tolpassa on kaksi kylttiä. Ylempi on oma katu, ja siinä on nuoli vasemmalle ja oikealle (katu jatkuu sivuille). Alempi on poikkikatu, ja siinä on nuoli ylös ja alas (siihen käännytään ylös tai alas).
- **Rantakadun pohjoispuolella on meri**, ja kartan reunoilla katu päättyy.
- Katujen järjestys on tiedostossa `scripts/city_map.gd`, jossa sitä on helppo korjata. *Avoinna:* osittaisten katujen (Ojakatu, Vaarankatu, Kajaaninkatu, Linnankatu, Heikinkatu) ja puistojen toteutus.
- **Maamerkit:** Kauppatori, kauppahalli, Rotuaari, tuomiokirkko, poliisiasema, rautatieasema, puistot (Snellmanin, Otto Karhin, Franzénin, Vaaranpuisto, Mannerheimin) ja kanava. Meri on luoteessa.
- Käytetään **oikeita kadunnimiä ja julkisia paikkoja**. **Yritysten nimet** (ravintolat, hotellit, kauppakeskukset) korvataan keksityillä nimillä.
- **Autoja liikkuu kaduilla harvakseltaan** (oikeanpuoleinen liikenne, satunnaisesti kumpaankin suuntaan). Autot pysähtyvät, jos joku (pelaaja tai muu hahmo) on suojatiellä, ja toisen auton taakse. Muualla tiellä kävelevän päälle auto ajaa. Pelaajalle käy satunnaisesti jokin näistä: tavallisimmin (65 %) **keula osuu** ja hahmo lentää heti rätkänukkena auton kulkusuuntaan (sitä kauemmas, mitä kovempaa auto ajoi; vie healthia 40, ja auto jarruttaa), välillä (25 %) **konepellille** (hahmo lennähtää konepellille, auto jatkaa 0,3–0,9 s ja jarruttaa, jolloin hahmo lentää kadulle ja menettää tajunnan hetkeksi) tai harvoin (10 %) **yliajo** (hahmo kaatuu heti auton alle, eikä auto hidasta lainkaan). Törmäyksessä kädessä oleva esine lentää pyörien korkeassa kaaressa ylös ja putoaa kadulle (pullo särkyy), ja noin joka kolmannella kerralla kengät lentävät jalasta muutaman metrin päähän: hahmo on paljain jaloin, kunnes hakee ne ("Etsi:"-listaan). Konepellille-tapaus vie healthia yhteensä 40, yliajo 55; ruutu pimenee ja hahmo makaa tajuttomana noin 4 s. Autot pysähtyvät tiellä makaavan hahmon eteen, ja ylös noustua auto ei osu 1,5 sekuntiin. Ohikulkija kaatuu, ja puolet kerroista hänen kenkänsä lentävät jalasta; jos pelaajan omat kengät ovat hukassa, hän voi ottaa ne (ne käyvät), muuten ne jäävät kadulle. Humalassa autoa on vaikeampi väistää. **Kävelykadulla (Rotuaari eli Kauppurienkatu) ei ole autoja lainkaan.** Autot ovat kiinteitä: niiden läpi ei voi kävellä. Kylkeen törmääminen saa toisinaan (noin joka kolmas kerta) auton pysähtymään, ja kuljettaja nousee tappelemaan; hän palaa autoon ja ajaa pois, kun pelaaja pakenee tarpeeksi kauas tai kun hän tokenee tyrmäyksestä. Takana tulevat autot jonottavat sillä aikaa.
- **Veteen voi pudota:** humalassa horjuva hahmo voi pudota rannasta, laiturilta tai kanavaan. Hän pääsee ylös, mutta on läpimärkä: **tulee todella kylmä**, ja vaatteet toimivat kuin ne olisivat hukassa, kunnes ne kuivuvat sisätiloissa. Kylmä vesi myös **piristää**, joten väsymys vähenee vähän. **Tavarat eivät huku** veteen pudotessa.
- **Rakennuksiin pääsee sisälle**, esimerkiksi kioskiin ja rautatieasemalle.
- Osassa rakennuksista on ovet kahdelle eri kadulle. Ne toimivat **oikoteinä**: yhdestä ovesta sisään, toisesta ulos eri kadulle.
- Aluksi toteutettavat sisätilat:

  | Paikka | Mitä siellä on |
  |---|---|
  | **Kioski** | ruokaa, juomaa, puhelimen lataus |
  | **Baari / pubi** | alkoholia, portsari, tappeluita |
  | **Kauppahalli** | ruokaa; oikotie kahden kadun välillä |
  | **Kauppakeskus** | lämmittelyä, vartijoita, oikoteitä |
  | **Rautatieasema** | pistorasia, vartijat, lämmin odotussali |
  | **Kirkko** | rauhallinen lämmittelypaikka; pappi voi auttaa; sunnuntaisin ehtoollisviiniä |
  | **Apteekki** | laastaria ja särkylääkettä rahalla; palauttaa vähän healthia |
  | **Kerrostalon rappu** | kodit, naapurit, varavaimet |

- Sisätiloissa pelimekaniikka on sama kuin kadulla (liikkuminen, tappelu, hahmot, tavarat). Ne vain näyttävät erilaisilta.
- Sisällä liikkuessaan hahmo **lämpenee hitaasti**. Pitkään ei kuitenkaan kannata lämmitellä, koska alkoholi laskee ja nälkä kasvaa.

## Pelin kulku

### Päivä = kenttä

1. **Ensimmäinen päivä alkaa kotoa**, joten pelaaja tietää, missä koti on. **Seuraavina päivinä hahmo herää aina jostain muualta** (juoppo on lähtenyt yöllä vielä liikkeelle), ja herätyspaikka on päivä päivältä kauempana kotoa. Näin jokainen päivä vaatii matkan kotiin, eikä pisteitä saa menemällä heti nukkumaan.
2. Osa tavaroista on hukassa, ja niitä etsitään kaupungilta.
3. Kotiin päästyään hahmo rojahtaa sänkyyn, sohvalle tai lattialle alkoholimäärästä ja väsymyksestä riippuen ja nukahtaa. Joskus pääsee pieru.
4. Seuraava päivä on uusi kenttä, ja se on aina edellistä vaikeampi.

### Koti

- **Kodin tyyppi vaihtelee** pelistä toiseen: esimerkiksi kerrostaloasunto (kerros arvotaan), kellarikomero tai kaverin sohva.

  | Koti | Erikoisuus |
  |---|---|
  | **Kerrostaloasunto** | tavallinen koti, paras uni. Ilman avaimia keinot ovat naapuri, ikkuna, lukkoseppä, varavain tai rappukäytävä (ks. Hukatut tavarat). |
  | **Kellarikomero** | kylmä: uni on huonompi ja aamulla ollaan vähän kylmissään. Ovessa on riippulukko, jonka voi rikkoa lyömällä, mutta se on meluisaa ja joku voi hälyttää poliisit. |
  | **Kaverin sohva** | avaimia ei tarvita, mutta ovikelloa pitää soittaa. Kaveri päästää sisään, jos tuo hänelle jotain (esim. juotavaa); muuten hän on joskus nukkumassa eikä avaa. |

### Vaikeutuminen

**Periaate: joka päivä jotain uutta.** Pelin edetessä pitää koko ajan tulla uusia asioita ja haasteita, jotta pelaaja kokee jatkuvasti jotain uutta ja haluaa pelata uudestaan nähdäkseen, mitä myöhemmin tulee vastaan. Uudet hahmot ja mekaniikat tuodaan peliin vähitellen päivä kerrallaan, ei kaikkea heti ensimmäisenä päivänä:

| Päivä | Uutta |
|---|---|
| 1 | perusasiat: ohikulkijat, poliisit, vartijat, portsari, kerjäläinen, kadun juoppo, autot |
| 2 | lokit ja punkkariporukat |
| 3 | koirat (voivat auttaa tai olla vihollisia) |
| 4 | pyöräilijät ja sähköpotkulaudat (kaahaavat jalkakäytävillä, myös kävelykadulla; soittavat kelloa tai tööttäävät, kun pelaaja on edessä, väistävät vähän, mutta kaatavat, jos ei väistä: 6 healthia) ja tölkinkerääjä (sininen kassi; ehtii roskiksiin ennen pelaajaa ja poimii kadulla lojuvat pullot ja tölkit) |
| myöhemmin | lisää ideoita alla (Tulevat haasteet) |

#### Tulevat haasteet (ideoita, ei vielä pelissä)

Uudet hahmot päivä kerrallaan:

- **Päivä 5:** **taskuvaras** (törmää ohimennen ja vie tavaran, joka muuttuu kesken päivän hukatuksi; saa takaisin kiinni ottamalla) ja **mummo** (hidas, mutta käsilaukku osuu kovaa).
- **Päivä 6:** **some-vaikuttaja** (kuvaa pelaajaa; video leviää ja poliisit tunnistavat loppupäivän helpommin) ja **pappi** (auttaja: antaa pullaa tai kahvia kylmissään tai nälkäiselle).
- **Päivä 7:** **lokkiparvet** (useampi lokki hyökkää ruoan perään yhtä aikaa) ja **poliisiparit**.
- **Päivä 8 ja myöhemmin:** **turisti** (kysyy tietä; oikea neuvo tuo rahaa), **ääripuolueen edustaja** (tunkee lentolehtistä, ei pääse eroon) ja **poliitikko** (vaalikoju: ilmaista kahvia ja karkkia).

Vaikeammat hukatut tavarat myöhempinä päivinä:

- tavara on **jonkun hallussa** (ostettava, vaihdettava tai napattava)
- tavara on **koiran suussa** (koira juoksee karkuun; makkaralla vaihtoon)
- tavara on **puussa tai katoksen päällä** (pudotettava heittämällä)

Erikoispäivät (satunnaisesti, tuovat vaihtelua):

- **Kärppien voittopäivä:** kaduilla juhlijoita, halaajia ja ilmaisia juomia, mutta myös enemmän tappeluita ja poliiseja.
- **Katujen siivouspäivä:** lakaisukone kulkee kadulla ja imaisee maassa olevat tavarat; hukatut tavarat pitää ehtiä hakea ennen sitä.
- **Myrsky:** tuuli työntää hahmoa, roskat ja lehdet lentävät, heitot kaartuvat.
- **Kova pakkanen:** kylmä kasvaa nopeasti, kadut liukkaita.
- **Tietyöt:** jokin katu on suljettu, ja pitää kiertää.
- **Poliisin puhallusratsia:** poliisi pysäyttää ja puhalluttaa; liian humalainen viedään putkaan.

Päivän pikkutehtävät (vapaaehtoisia, palkintona rahaa tai pisteitä): esimerkiksi vie kaverille makkara, palauta löydetty lompakko omistajalleen, hae juoppo-tutulle pullo.

Päivät vaikeutuvat lisäksi vähitellen kolmella tavalla:

- **Etsintäsäde kasvaa:** koti ja hukatut tavarat ovat kauempana toisistaan.
- **Enemmän hukattua:** joka päivä hukkuu useampi tavara.
- **Vaarallisempi kaupunki:** poliiseja, vartijoita, vihaisia koiria ja punkkariporukoita on enemmän.

Krapula ei kovene päivien mukaan.

**Ensimmäisenä päivänä** hukassa on **1–2 tavaraa**, jotta pelaaja oppii mekaniikat rauhassa. Yleensä ne ovat helppoja, kuten aurinkolasit, mutta joskus hukassa on lompakko.

### Hukatut tavarat

- **Ajatuskupla aamulla:** päivän alussa hahmon pään yläpuolelle tulee ajatuskupla, jossa näkyvät vain hukassa olevat tavarat (yliviivattuina). Kupla pysyy näkyvissä, kunnes pelaaja on kävellyt noin 5 metriä.
- Sen jälkeen **puuttuvat tavarat näkyvät koko päivän ruudun yläreunan keskellä** tekstin "Etsi:" perässä harmaina ikoneina. Löydetty tavara muuttuu värilliseksi ja saa vihreän rastin.
- **Löydetty oma tavara menee suoraan omalle paikalleen**: lompakko taskuun, kengät jalkaan ja niin edelleen. Harmaa ikoni muuttuu värilliseksi. Käden tavara ja pussi pysyvät ennallaan.
- **Humala vie muistin:** kun promillet nousevat yli 1,3 ‰ (kolmasosa), 1,9 ‰ (kaksi kolmasosaa) ja 2,4 ‰ (kaikki), hukkalistan ikoneita muuttuu yhtäkkiä tunnistamattomiksi harmaiksi läiskiksi. Pelaaja ei enää muista, mitä oli etsimässä. Kun promillet laskevat rajan alle, muisti palaa ja ikonit näkyvät taas.
- Joka päivä hukkuu uusia tavaroita. Aiemmin hukatut pysyvät hukassa, kunnes ne löytyvät.
- Jokaisen puuttuvan tavaran puute haittaa peliä jollain tavalla. Esimerkkejä:
  - **Lompakko:** ei voi ostaa mitään. Ensimmäisenä päivänä lompakko voi olla hukassa.
  - **Puhelin:** ilman sitä ei saa vihjeitä eikä tiedä sijaintiaan (ks. alla).
  - **Silmälasit:** ilman niitä näkökenttä on lyhyempi (ks. alla).
  - **Aurinkolasit:** aurinkoisella säällä pelaaja ei juuri näe, kun kulkee aurinkoa vasten (ks. alla).
  - **Vaatekappaleet:**
    - Jokainen puuttuva vaatekappale saa hahmon kylmettymään nopeammin, ja kylmä kasvattaa taas nälkää nopeammin.
    - **Kengät:** ilman niitä vauhti on hitaampaa, ja juokseminen on mahdollista mutta vaikeampaa. Hyötynäkin on: paljain jaloin pelaaja voi **hiippailla**. Hiippaillen voi ohittaa poliisit ja vartijat huomaamatta, yllättää ohikulkijan selän takaa ja **taskuvarastaa** helpommin.
    - **Takki ja housut:** suojaavat tappeluissa.
  - **Avaimet:** ilman niitä kotiovi on lukossa. Kotiin pääsee silti muilla keinoilla, joista jokainen maksaa jotain:
    - **Naapurin ovikello:** naapuri voi päästää sisään, haukkua tai soittaa poliisille (satunnaista).
    - **Ikkuna tai parveke:** onnistuu, jos asunto on alakerrassa. Putoaminen vie healthia, ja ohikulkija voi luulla murtautujaksi ja hälyttää poliisit.
    - **Lukkoseppä:** vaatii puhelimen (akkua) ja lompakon (rahaa). Kallis, mutta varma.
    - **Varavain:** joskus kuramaton alla tai kaverilla toisella kadulla, jonka luo pitää löytää.
    - **Rappukäytävä:** hahmo nukahtaa oman oven taakse. Lasketaan muualla nukahtamiseksi: uni on huonompi ja hahmo on aamulla kylmissään.
  - **Henkilökortti:** ilman sitä baarissa ja kaupassa ei myydä alkoholia, ja poliisi pitää pidempään putkassa.
  - *(lisää myöhemmin)*
- *Avoinna:* muiden tavaroiden tarkka haittavaikutus.

### Tavara kädessä ja muovipussit

- **Hahmo kääntyy pehmeästi kulkusuuntaan**, myös ylös, alas ja viistoon (heittoa tähdätessä tähtäyssuuntaan). Samoin kaikki muut hahmot (ohikulkijat, poliisit, vartijat, kuljettajat); paikallaan tappeluun valmistautuessaan ne katsovat pelaajaa.
- **Kontrollit ovat helpot.** Tavarat poimitaan automaattisesti kävelemällä niiden päälle.
- Hahmolla on **yksi tavara kädessä**. Kun hän koskee uuteen tavaraan, käden tavara **vaihtuu automaattisesti** uuteen.
- Kadulla voi olla **muovipusseja**, jotka hahmo nappaa käteen automaattisesti päälle kävellessään.
- Kun pussi on kädessä, uudet tavarat **menevät pussiin**, eikä pussi vaihdu. Pussiin mahtuu muutama tavara, esimerkiksi tölkkejä pullonpalautukseen.
- Pussi voi **revetä**, jos siihen laittaa liikaa tai pelaaja tappelee. Silloin tavarat leviävät kadulle.
- **Kaikkia tavaroita voi heittää**, myös pussin tavaroineen.

### Kontrollit

- Kontrollien pitää olla niin simppelit, että peliä voi pelata **puhelimella**.
- Käytössä on **suuntanuolet**, **toimintanappi** ja erillinen **puhelinnappi**.
- **Puhelimella** suuntanuolten tilalla on **ohjaussauva** näytön vasemmassa alareunassa: sauvan keskiö ilmestyy siihen, mihin sormi osuu, ja sormea liu'uttamalla hahmo kävelee; kun sormen vie reunaan asti (keltaisen renkaan yli), hahmo juoksee.
- Toimintanapissa on **lyhyt ja pitkä painallus**:

  | Toiminto | Kontrolli |
  |---|---|
  | **Lyö** (nopea lyönti) | lyhyt painallus: käsi nousee suorana eteen |
  | **Ladattu lyönti** (käsi tyhjä) | pitkä painallus: käsi koukistuu kyynärpäästä ja vetäytyy taaksepäin (nyrkki olkapään tasolle); lataus täyttyy sekunnissa, ja päällä näkyy latausrengas. Lyönti lähtee suorana eteen, kun nappi päästetään. Mitä pidempi lataus, sitä kauemmas vastustaja lentää ja sitä enemmän kuntoa kuluu (väliaikaista healthia 4–12). Täysi lataus tekee yhden vahingon enemmän (selvin päin 2, humalassa 3). |
  | **Syö / juo** käden tavara | lyhyt painallus, kun lähellä ei ole ketään |
  | **Mene sisään** | lyhyt painallus ovella |
  | **Heitä** käden tavara | pitkä painallus; mitä pidempään pitää pohjassa, sitä pidemmälle lentää. Latauksen aikana hahmo ei liiku, vaan nuolilla valitaan heiton suunta (myös ylös ja alas). Heitto lähtee, kun nappi päästetään. |
  | **Juokse** | kaksoisnapautus suuntanuolta (toisella napautuksella nuoli jää pohjaan) tai Shift pohjassa nuolen kanssa (peliohjaimella RB); puhelimella ohjaussauva reunaan asti. Pelkkä suunnan pitäminen pohjassa on aina kävelyä. |

- Kun toimintanappi on pohjassa (lyönnin tai heiton lataus), **koko peli kulkee puolella nopeudella**: ohikulkijat, autot, kello ja myös pelaaja itse.
- **Lääkkeet:** roskiksesta voi joskus löytää lääkkeitä. Ne vaikuttavat heti löydettäessä: latauksen aikana vain muu maailma hidastuu ja pelaaja liikkuu täydellä nopeudella noin 90 sekunnin ajan (pelin aikaa). Se on vahva etu, jolla ehtii väistää.
  | **Puhelin auki / kiinni** | oma puhelinnappi (kosketusnäytöllä pieni nappi ison napin yläpuolella, näppäimistöllä P tai Tab, peliohjaimella Y); lisäksi ruudun oikeassa yläkulmassa on puhelinkuvake, jota napauttamalla tai klikkaamalla puhelimen saa auki, ja sen alla on P-näppäimen kuva (kosketusnäytöllä ei) |
  | **Puhelimen selaus** | vasen / oikea |

### Näkökenttä ja silmälasit

- Kentillä on kaikenlaista tavaraa, joka näkyy epäselvänä ja **selkenee vasta, kun sen lähelle menee**. Joskus se on hukattu tavara, joskus vain sitä muistuttava roska tai muu esine.
- Kaukaa esineen **muoto vihjaa**, mitä se voi olla. Esimerkiksi kenkämäinen möykky voi olla omat kengät tai vanha saapas.
- **Omat tavarat eivät hehku eivätkä erotu muista** ennen kuin ne ovat lähellä. Pelaajan pitää tutkia epäilyttäviä möykkyjä.
- **Ilman silmälaseja** tämä näkökenttä on lyhyempi.
- **Ilman silmälaseja** kadunnimikyltit ovat sumeita, ja niistä saa selvää vasta aivan vierestä.
- **Humalassa** (yli 1,3 ‰) kyltin kirjaimet menevät sekaisin: yli 5 metrin päästä kyltissä on mitä sattuu kirjaimia. Lähempänä kuin 5 metriä kirjaimet ovat oikeat, mutta ne pyörivät uuteen järjestykseen jokaisella askeleella. **Jokaisella kyltillä on oma kohta** (eri kyltillä eri paikassa) kyltin lähellä: mitä lähempänä sitä kohtaa ollaan, sitä useampi kirjain on oikealla paikallaan, ja oikea nimi näkyy vasta aivan siinä kohdassa.
- Jos on humalassa ja lasit hukassa, molemmat efektit ovat voimassa.
- Sama koskee kauppojen kylttejä (kioski, baari).

### Aurinko ja aurinkolasit

- Pelissä on aurinko, joka paistaa aina **tietystä ilmansuunnasta** kaupungin kartalla.
- Kadut ovat eri suuntiin, joten auringon suunta ruudulla riippuu kadusta. Jos aurinko näkyy taustalla talojen välistä ja pelaaja kääntyy risteyksestä 90 astetta toiselle kadulle, aurinko paistaa sen jälkeen sivulta, esimerkiksi oikealta.
- **Varjot** vaihtavat suuntaa samalla tavalla.
- Aurinko **liikkuu päivän mittaan** pelin kellon mukaan. Kello etenee vain, kun pelaaja liikkuu tai tekee jotain, joten aurinko etenee samassa tahdissa.
  - Häikäisy ja aurinkolasien tarve vaihtelevat kellonajan ja kadun suunnan mukaan.
  - Kellonajan näkee maailmasta, vaikka puhelin olisi hukassa.
  - Iltaa kohti tulee hämärää ja pimeää. **Mitä pimeämpää on, sitä nopeammin väsymys kasvaa.** Päivä päättyy siis luontevasti nukahtamiseen, jos kotiin ei ehdi.
  - **Mitä myöhemmin hahmo menee nukkumaan tai nukahtaa, sitä myöhemmin hän herää seuraavana päivänä**, kuten oikeastikin. Myöhäinen herätys jättää vähemmän valoisaa aikaa.
  - **Pelipäivän pituus on noin 3 minuuttia** oikeaa aikaa, jos pelaaja liikkuu koko ajan. Peli on nopea, ja yksi pelin tunti vastaa siis vain muutamaa sekuntia liikettä.
- Aurinkoisella säällä pelaaja **ei juuri näe aurinkoa vasten kulkiessaan, jos aurinkolasit ovat hukassa**.

### Sää

- **Joka päivä on eri sää**, ja se arvotaan satunnaisesti.
- **Aurinkoisella säällä kaduilla ja seinillä liikkuu pilvien varjoja.** Ne liikkuvat tuulen mukana vain silloin, kun aika kulkee, ja osuvat samaan suuntaan kuin auringon varjot.

  | Sää | Vaikutus |
  |---|---|
  | **Aurinkoinen** | häikäisee aurinkoa vasten kuljettaessa, jos aurinkolasit ovat hukassa: hahmo nostaa vasemman käden otsalle lipaksi, ja ruudun yläreunaan laskeutuu vaakasuora käsi lipaksi, joka peittää lähes koko yläreunan (kyynärvarsi vasemmalta, sormet oikealle, valoa siivilöityy sormien välistä) kuin pelaajan omaan näkökenttään (käsi vähentää häikäisyä vähän) |
  | **Pilvinen** | neutraali; aurinkolaseja ei tarvita |
  | **Sade** | kylmettyy nopeammin ilman takkia; lätäköitä, joista pyöräilijät roiskivat; näkyvyys hieman huonompi |
  | **Lumi ja pakkanen** | kova kylmä; liukkaat kadut, joten juostessa voi kaatua ja menettää healthia; kengättä erityisen vaikeaa |

### Puhelin

- Puhelin auttaa vain **tavaroiden löytämisessä** ja **oman sijainnin selvittämisessä**.
- Käyttö on hyvin yksinkertaista: näkymiä selataan vain sivusuunnassa tässä järjestyksessä:
  1. **Viestit:** näkyvät listana kuten WhatsAppissa. Viestit ovat **enimmäkseen emojeja ja pieniä kuvia**, ja välissä on muutama sana, kuten kadunnimi (esim. 🍺➡️ Kirkkokatu 👟❓). Niistä saa vihjeitä siitä, missä hahmo oli eilen.
  2. **Viimeisin kuva:** kertoo, missä hahmo oli eilen. Kuvassa voi näkyä jokin hukattu tavara.
  3. **Kartta:** näyttää, missä hahmo on juuri nyt ja missä koti on (talon kuva).
- **Akku:** virtaa on aina todella vähän. Akku kuluu vain silloin, kun puhelinta käytetään (puhelin auki), ja mitä pidempään sitä käyttää, sitä enemmän akkua kuluu. Kartta kuluttaa akkua nopeimmin.
- Puhelinta käytettäessä **maailma on pysähdyksissä**, mutta akku kuluu.
- Kun akku loppuu, näytölle tulee hetkeksi vilkkuva tyhjän akun kuva, ja sitten puhelin sulkeutuu. Sama kuva näkyy, jos puhelimen yrittää avata tyhjällä akulla.
- Akkua voi **ladata** esimerkiksi rautatieaseman pistorasiassa. Lataaminen on **vaihtokauppa**: aika harppaa hetken eteenpäin, puhelimeen tulee tietty määrä akkua (aina vain vähän), ja samalla alkoholi laskee ja nälkä kasvaa.
  - Muut hahmot liikkuvat harppauksen aikana, joten sen jälkeen tilanne on hieman eri. Muutos on realistinen eikä aina haasteellinen, koska pelaaja maksoi jo alkoholilla ja ruoalla.
- Viestien ja kuvien olemassaolo on **satunnaista**. Joka päivä hahmo ei välttämättä ole saanut viestejä tai ottanut kuvia.
- Kuvat ovat aina **todella huvittavia**. Niissä voi olla alastomuutta, mutta se on peitetty sumealla esineellä, joka on muka vahingossa osunut eteen.

### Viikonpäivät ja rannekello

- Pelissä on viikonpäivät. **Ensimmäinen pelipäivä on satunnainen viikonpäivä**, eikä pelaaja tiedä, mikä se on.
- **Sunnuntaisin** (joka 7. pelipäivä) kirkossa on **ehtoollisviiniä**, eli ilmaista alkoholia.
- **Rannekello:** jos pelaaja saa varastettua jollekulta rannekellon, siitä näkee, mikä viikonpäivä on. Silloin hän tietää, milloin on sunnuntai.

## Pelattava hahmo

- Pelin alussa valitaan **mies tai nainen**. Valinta ei vaikuta pelimekaniikkaan.
- **Vaatetus vaihtelee** myöhemmin, mutta sitä ei toteuteta vielä ensimmäisessä versiossa.

## Hahmon tila

| Tila | Näyttötapa | Seuraus |
|---|---|---|
| **Health** | sydän, josta väri valuu pois; ei tarkkaa lukemaa. Alle 15:ssä sydän sykkii ja hehkuu punaisena (vaara, mutta vielä hengissä) | kuolema, kun nollassa |
| **Alkoholi** | **tarkka lukema promilleina** (esim. 1,4 ‰) pulloikonin sisällä, koska alkoholi on pelin tärkein muuttuja | kuolema, kun nollassa |
| **Väsymys** | ei mittaria: silmät alkavat painua kiinni, ryhti lysähtää, hahmo haukottelee ja päästä nousee välillä Zzz-ikoni | nukahtaa, kun täynnä (ks. alla) |
| **Kylmä** | ei mittaria: hahmo tärisee | nälkä kasvaa nopeammin ja health kuluu |
| **Nälkä** | ei mittaria: maha kurisee, hahmo näyttää nälkäiseltä | health kuluu; alkoholi nostaa alkoholimittaria tavallista enemmän (tyhjään mahaan) |

### Promillerajat

- **Juoma imeytyy hitaasti:** promillet eivät nouse heti juodessa, vaan kukin juoma imeytyy noin 20 sekunnin aikana (pelin aikaa; aluksi nopeammin, lopuksi hitaammin), ja health palautuu samassa tahdissa. Jokaisella juomalla on oma imeytymisensä, joten monta peräkkäin nostaa promilleja nopeammin. Juodessa ei näytetä määrää (vain "glug"), joten pelaaja ei tiedä tarkalleen, mihin humala vielä nousee, ja liikaa voi juoda vahingossa.

Humalan vaikutukset alkavat matalammalla kuin alussa suunniteltiin (kaikki rajat siirrettiin 0,7 ‰ alemmas); sammumisraja arvotaan joka päivä 3,2–4,0 ‰.

| Promillet | Tila |
|---|---|
| **0 ‰** | kuolema |
| **alle 0,5 ‰** | krapula: health kuluu sitä nopeammin, mitä selvempi hahmo on (0,8 / s rajalla, 4 / s lähellä nollaa). Ruudulla pullo vilkkuu punaisena, punainen nuoli sykkii pullosta sydämeen ja sydämestä tippuu punaisia pisaroita; rajan alittuessa hahmon yllä välähtää "‰!". Hahmo tärisee (sitä pahemmin, mitä kovempi edellispäivän humala oli; ks. Krapulatärinä), lyönnit ovat heikkoja ja health kuluu hitaasti. Varoitus, että juotavaa pitää löytää. |
| **0,5–1,3 ‰** | sopiva alue, hahmo toimii normaalisti |
| **1,3 ‰ – sammumisraja** | humalan haitat (horjuminen, sumea näkökenttä, rohkeus) voimistuvat vähitellen |
| **yli 3,2–4,0 ‰** | hahmo sammuu (raja arvotaan joka päivä 3,2 ja 4,0 ‰ väliltä, joten sitä ei voi tietää tarkasti) |

- Promillet laskevat tasaisesti, kun pelaaja liikkuu tai tekee jotain.

### Uni ja aamun lähtötilanne

- **Aamun promillet riippuvat siitä, kauanko hahmo ehti nukkua.** Lyhyt uni jättää enemmän promilleja vereen, pitkä uni vähemmän. Myös nukkumaan mennessä veressä olleet promillet vaikuttavat.
- **Unen pituuteen ja laatuun vaikuttavat monet tekijät**, esimerkiksi:
  - **Paikka:** kotona sängyssä nukkuu parhaiten. Pihalla, rappukäytävässä tai putkassa uni jää lyhyeksi.
  - **Kylmä ja nälkä** heikentävät unta.
  - **Nukkumaanmenoaika:** mitä myöhemmin, sitä myöhemmin herätään (ks. Aurinko).
- Esimerkiksi pihalta herännyt on nukkunut lyhyesti, joten hänellä on aamulla enemmän promilleja veressä.
- **Uni laskee promilleja aina vähintään 0,6 ‰**, mutta aamu ei ala alle 0,25 promillesta (muuten päivä päättyisi heti).
- **Uni aiheuttaa nälkää.** Kylmä yö (katu, rappu, kellari) kasvattaa nälkää enemmän.
- **Unen laatu vaikuttaa kaikkeen:**
  - **Health:** hyvä yö kotona palauttaa healthin lähes täyteen, huono yö vähemmän.
  - **Väsymys** nollautuu yön aikana **lähes kokonaan** aina. Huonon yön jälkeen jää vain pieni jäännös.

### Healthin palautuminen

- **Uni:** yöunet palauttavat suurimman osan. Kotona nukkuminen palauttaa eniten.
- **Ruoka:** syöminen palauttaa vähän.
- **Hyvä humala korjaa:** 1,0–2,5 promillessa health palautuu itsestään hitaasti (0,4 / s liikkuessa). Selvempänä tai kovemmassa humalassa ei.
- **Alkoholi:** juominen palauttaa healthia juoman vahvuuden mukaan (15 healthia promillea kohden: olut noin +4, pullo +6, tuoppi +8, viina +9, tuntematon aine +14; tyhjään mahaan enemmän).
- **Apteekki:** laastaria tai särkylääkettä saa rahalla, mutta ne palauttavat vain vähän.
- Päivän aikana health ei palaudu itsestään.

### Väsymyksen vähentäminen

- **Kahvi ja energiajuoma** vähentävät väsymystä hetkeksi. Niitä löytää **harvoin**.
- Liika kofeiini saa hahmon tärisemään, jolloin lyönnit menevät ohi.

### Humala

Mitä enemmän alkoholia, sitä voimakkaammin nämä vaikuttavat:

- **Horjuminen:** ohjaus ei mene aivan suoraan, ja lyönnit menevät joskus ohi.
- **Vinjetti (yli 0,8 ‰):** näkökentän reunat tummuvat, ja tummuus voimistuu ja leviää kohti keskustaa promillejen noustessa (voimakkaimmillaan sammumisrajalla).
- **Hikka (yli 0,8 ‰):** hahmo hikkaa välillä ("hik!") ja nytkähtää. Hikan hetkellä taskuvarkaus paljastuu aina.
- **Rakkaus kaikkiin (1,3–1,8 ‰):** hahmo halaa ohikulkijoita, joihin törmää. Halauksen aikana taskuvarkaus onnistuu lähes aina, eikä halattu suutu.
- **Laulaminen (yli 1,5 ‰):** hahmo alkaa välillä laulaa (nuotteja nousee). Lähellä olevat ohikulkijat voivat suuttua, ja poliisit voivat huomata.
- **Rohkeus ja ohilyönnit (yli 1,3 ‰):** lyönnit tekevät tuplavahinkoa, mutta menevät sitä useammin ohi, mitä kovempi humala. Poliisit ja vartijat huomaavat rikoksen kaksi kertaa kauempaa myös hiippaillessa.
- **Kaatuilu:** hahmo voi kaatua vain, kun alusta vaihtuu (reunakiven yli ajotieltä jalkakäytävälle tai takaisin) tai kun hän kävelee jotain päin (puu, lyhtypylväs, penkki, roskis, kyltin tolppa). Kaatuminen on satunnainen yllätys: reunakiven ylityksessä 2 % (1,3 ‰) – 15 % (2,8 ‰), esteeseen törmätessä 8 % – 35 %; juostessa 1,5-kertaisesti ja lumella lisää 2 prosenttiyksikköä (kengättä 4). Lumella voi lisäksi liukastua jyrkässä käännöksessä (yli 75°) vasta 1,5 promillesta alkaen, enintään yksi arvonta kahdessa sekunnissa (4–20 % täyskäännöksessä humalan mukaan). **Juostessa reunakiven yli** kaatumisen riski on aina olemassa, myös selvin päin, ja kasvaa humalan mukana (lisäksi 3 % + 6 % promillea kohden). Kävellen eteneminen on suhteellisen turvallista. **Jos hahmoa väsyttää** (silmät alkavat painua kiinni) **tai silmät luppaavat humalasta** (noin 2,0 promillesta alkaen), kaatuminen päättyy 50 %:n todennäköisyydellä nukahtamiseen: hahmo jää maahan nukkumaan, ja päivä päättyy kadulle. Selvin päin kuivalla kadulla hahmo vain törmää esteeseen ja pysähtyy. Esteiden läpi ei voi kävellä.
- **Tuplanäkö (yli 2,3 ‰):** kuva näkyy kahtena.
- **Krapula (alle 0,5 ‰):** hahmo tärisee, ja joka toinen lyönti on niin heikko, ettei se tee vahinkoa.
- **Hassu kävely:** humalan noustessa kävely muuttuu pikkuhiljaa hassummaksi: alkaen 1,8 promillesta, voimakkaimmillaan noin 2,5 promillessa. Hassu kävely on absurdin liioiteltua: korkeita potkuja eteen, heiluvat kädet, pomppiva askel ja taaksepäin kallistuva vartalo.
- **Väärä suunta:** kovassa humalassa (yli 2,3 ‰) hahmo lähtee välillä eri suuntaan kuin nuoli osoittaa. Alle 3 promillessa harvoin (noin 14 s välein 2,3 ‰:ssä) ja vain vähän sivuun (45°, menee ohi alle puolessatoista sekunnissa); 3 promillesta ylöspäin useammin (lähellä sammumista noin 3 s välein) ja jyrkemmin (esim. oikealle painettaessa ylös, menee ohi noin 1,5–3 sekunnissa). Pelaaja voi korjata heti painamalla siihen suuntaan, johon hahmo oikeasti menee. Juostessa vähän useammin kuin kävellessä. Väärä suunta voi olla mikä tahansa kahdeksasta suunnasta (myös viistoon), mutta **ei koskaan suoraan vastakkainen**. Jos väärä suunta veisi seinää tai reunaa päin, se peruuntuu, jottei hahmo jää kävelemään paikallaan.
- **Rohkeus:** lyönnit ovat kovempia ja kylmä tuntuu vähemmän, mutta poliisit huomaavat pelaajan helpommin.
- **Turtumus:** humalassa iskut ja kaatumiset sattuvat vähemmän, ja mitä kovempi humala, sitä vähemmän: vahinko pienenee tasaisesti 0,5 promillesta alkaen (2,0 promillessa noin neljänneksen) aina päivän sammumisrajaan asti, jossa se on 60 % pienempi. Ilman humalaa pelaaja kuolee helpommin.
- **Näkökenttä:** 1,0 promillesta alkaen kuva sumenee (aluksi lievästi): pelihahmon ympärillä olevan ympyrän sisällä vähän, ulkopuolella enemmän, ja sitä enemmän mitä kovempi humala. Ympyrä pienenee nopeasti koko ruudun kokoisesta (1,0 ‰) 1,5 metrin säteeseen (2,3 ‰) ja siitä edelleen 0,8 metriin päivän sammumisrajalla. Yli 2,3 promillessa sumennus ympyrän ulkopuolella voimistuu selvästi. Kaikki näkökentän efektit (sumennus, tuplanäkö, vinjetti) voimistuvat aina sammumisrajaan asti.
- **Silmäluomet:** noin 2,0 promillesta alkaen ruudun ylä- ja alareunasta painuu välillä tummat, kaarevat silmäluomet (ruudun ylä- ja alareunassa lähes läpinäkymättömät, reunaa kohti läpikuultavammat) (aluksi noin 14 s välein, lähellä sammumista noin 3,6 s välein). Mitä kovempi humala, sitä pidempään ne pysyvät lähes kiinni (0,9 s → 3 s), kuin hahmo meinaisi nukahtaa. Lähellä sammumisrajaa luomet roikkuvat jatkuvasti puoliksi kiinni. Hahmon lähellä kuva pysyy selvimpänä.
- **Sammuminen:** kun promillet ylittävät päivän sammumisrajan (arvotaan joka päivä 3,2–4,0 ‰), hahmo sammuu paikalleen. Se lasketaan nukahtamiseksi.

### Nukahtaminen väsymyksestä

- **Kadulla nukutun yön jälkeen** housut ovat takamuksesta ruskeat ja edestä keltaiset. Tahrat pysyvät, kunnes hahmo nukkuu kotona tai kaverilla. Portsari ei päästä likaista baariin.
- **Kadulle nukahtaminen etenee vaiheittain** (väsymys täynnä, sammumisraja ylittyy tai kello tulee 24): ensin silmäluomet painuvat noin 1,5 sekunnissa lähes kiinni ja hahmo huojuu paikallaan, sitten hän lysähtää kadulle (rätkänukke), ja vasta hetken päästä silmät menevät kokonaan kiinni ja päivä vaihtuu.

- Kun väsymys on täynnä, pelaaja nukahtaa siihen paikkaan, missä on.
- Hän herää seuraavana aamuna, eli seuraavasta kentästä.
- Hän herää aina jostain muualta kuin kotoa (ks. Päivä = kenttä). Nukahtamispaikka vaikuttaa silti aamun promilleihin, healthiin ja nälkään.

## Rahan hankinta

- **Taskuvarkaus:** hahmo on kleptomaani ja näpistää automaattisesti (ks. Ryöstely).
- **Ryöstely:** tyrmätty ohikulkija voi pudottaa rahaa (ks. Ryöstely).
- **Pullonpalautus:** pantillisia tölkkejä ja pulloja kerätään kadulta ja palautetaan kioskissa tai kauppakeskuksessa. Tölkinkerääjä kilpailee samoista tölkeistä.
- **Kolikoita maasta:** näkyvät epäselvinä kuten muutkin esineet ja selkenevät lähelle mentäessä.
- **Katusoitto:** onnistuu, jos löytää soittimen tai pahvimukin.
- **Kerjäämistä ei toteuteta**, koska se on hidasta eikä sovi nopeatempoiseen peliin.

## Ruoan ja alkoholin hankinta

- **Ostaminen:** kioskista, baarista ja kauppahallista (vaatii lompakon ja rahaa).
- **Ryöstely ja taskuvarkaus:** ohikulkija voi pudottaa ruokaa tai alkoholia.
- **Kadun juoppo:** voi tarjota huikan vaihtokauppana.
- **Roskiksen penkominen:** toimintanappi roskiksen vieressä (jalkakäytävän seinänpuoleisella reunalla). Ovien (kaupat, baari, koti, poliisiasema) molemmin puolin jätetään 3 metriä tyhjää: sinne ei tule roskiksia, puita eikä kerjäläisiä, jottei nappi sekoita ovea ja roskista. Penkomattoman roskiksen yläpuolella näkyy suurennuslasi, kun pelaaja on lähellä; aivan vieressä näkyy lisäksi napin kuva → suurennuslasi. Penkotussa roskiksessa ei näy vihjettä. Noin 70 %:ssa roskiksista on pullo: olutta (+0,25 ‰), viinaa (+0,6 ‰) tai tuntematonta huumaavaa ainetta (+0,9 ‰, violetti pullo käsin kirjoitetulla etiketillä). Harvoin (noin joka 13. roskis) löytyy lääkkeitä, jotka vaikuttavat heti (ks. Lääkkeet). Löytö menee käteen. Kukin roskis penkoo kerran päivässä; sisältö pysyy samana koko päivän (myös palatessa kortteliin) ja arvotaan uudelleen seuraavana aamuna. *(Lokit myöhemmin.)*
- **Terassilta varastaminen:** pelaaja nappaa juoman pöydältä ohi kulkiessaan. Asiakas tai portsari voi suuttua.
- **Hukatut pullot ja eväät:** kadulla on muiden hukkaamia pulloja ja eväitä. Ne näkyvät epäselvinä kuten muutkin esineet.
- **Ehtoollisviini:** kirkossa sunnuntaisin (ks. Viikonpäivät ja rannekello).
- **Ilmaiset maistiaiset:** kauppahallissa tai kauppakeskuksessa, mutta **vain joskus** (satunnaista, ei joka päivä). Myyjä muistaa, jos käy hakemassa liian monta kertaa.

## Tappelu

- **Parannettavaa:** tappelumekaniikka on vielä aika huono (lyönneissä ei ole painoa, osuman tuntuma on heikko ja vastustajat ovat ennalta-arvattavia). Parannusideat: issue #40 (osuman tuntuma, osumareaktiot, väistö ja vastahyökkäys, vastustajien vaihtelu, yhdistelmät, ympäristö ja ryhmätappelun vuorottelu). Ladatun lyönnin käsianimaation pitää näkyä selvästi (käsi koukkuun ja taakse): issue #41.

- Pelissä on tappelua. Pelaaja voi lyödä muita, ja muut voivat hyökätä pelaajan kimppuun.
- **Rämpytys ei kannata:** yksi lyönti on ilmainen, mutta jos lyö uudestaan heti perään (alle 0,7 s), health kuluu väliaikaisesti (7 / lyönti). Väliaikainen kulutus näkyy sydämessä vaaleanpunaisena, ja jokaisesta liian nopeasta lyönnistä pelaajan pään päälle ilmestyy sydän, joka tyhjenee (punainen vähenee ja vaaleanpunainen kasvaa); se näkyy pari sekuntia viimeisen lyönnin jälkeen ja koko uupumuksen ajan. Myös **juokseminen** kuluttaa healthia väliaikaisesti (3 / s; täysi sydän riittää noin 33 sekunnin eli 6–7 korttelin juoksuun). Kun pelaaja ei ole lyönyt eikä juossut 5 sekuntiin, vaaleanpunainen osa palautuu hitaasti, mutta vain liikkuessa (paikallaan seisten aika ei kulje, eikä mikään palaudu). Kun väliaikainen kulutus vie koko healthin (koko sydän vaaleanpunainen), pelaaja on **uupunut** (hengästynyt), kunnes noin 30 % sydämestä on taas punaista: hahmo lyö vain noin kerran kahdessa sekunnissa ja jaksaa juosta vain muutaman askeleen kerrallaan (kaksoisnapautuksella tai ohjaussauvalla). Uupunut hahmo hengittää raskaasti (rintakehä nousee ja laskee, hengityshöyryä nousee) myös paikallaan seistessä.
- **Healthin koko määrä kuvastaa kuntoa:** sydän saa olla kokonaan vaaleanpunainen vain hetken. Täydellä healthilla aikaa on 10 sekuntia, lähes tyhjällä vain 1 sekunti (pelin aikaa). Sen jälkeen health alkaa vähetä vähitellen, kunnes pelaaja lepää ja punainen alkaa taas nousta.
- **Yllätyslyönti selkään:** jos lyö hahmoa takaapäin (hahmo vain kävelee tai seisoo eikä tappele, ajaa takaa tai istu, ja sen kasvot osoittavat yli 105° poispäin pelaajasta), kohde ei ehdi puolustautua. Lyönti tekee tuplavahingon (krapulankin heikko lyönti osuu), ohilyöntejä tulee puolet vähemmän, ja täysin ladattu yllätyslyönti tyrmää heti. Tyrmätty kaatuu eteenpäin kasvoilleen. Palautteena kohteen pään päällä näkyy iso punainen "!" ja iso osumatähti. Poliisia ja vartijaa yllätyslyönti ei tyrmää, mutta ne horjuvat pidempään (1,6 s). Saavutus: Selkäsauna.
- **Erillistä torjuntaa ei ole.** Iskuja voi väistää liikkumalla, esimerkiksi ylös tai alas kadun syvyyssuunnassa.
- Osalla hahmoista isku näkyy hetkeä ennen osumaa (esim. käsi nousee), mutta **kaikista hahmoista ei näe, milloin ne ovat lyömässä**.
- **Heittäminen:** heitetyn esineen vaikutus riippuu esineestä:
  - **Kevyt esine** (tölkki, tyhjä muovipussi) ärsyttää kohdetta mutta ei juuri satuta.
  - **Raskas esine** (pullo, täysi pussi) tainnuttaa kohteen hetkeksi. Prototyypissä: pullo 60 % ja täysi energiajuomatölkki 40 % todennäköisyydellä (tyhjä tölkki on kevyt); kohde makaa 3–5 sekuntia ja nousee vihaisena.
  - **Ruoka** houkuttelee lokit ja koirat paikalle. Sillä voi harhauttaa vihaisen koiran.
- **Heitettävät esineet ovat fysiikkaesineitä:** heitetty esine lentää, pyörii, pomppii seinistä ja maasta ja jää makaamaan kyljelleen siihen, mihin päätyi. Osuma ihmiseen tai eläimeen kimmottaa sen takaisin. Pullo särkyy ensimmäiseen osumaan. Makkara on löysä: kädessä sen päät roikkuvat ja heiluvat liikkeen mukana, lennossa se vipattaa ja maassa se lojuu loivalla mutkalla.
- **Tappelija ei jää kävelijästä:** vihainen jalankulkija liikkuu nopeammin kuin pelaaja kävelee (3,2 vs. 2,6 m/s) mutta hitaammin kuin pelaaja juoksee. Lyönti alkaa jo vajaan puolentoista metrin päästä, ja valmistelun aikana hän astuu perään, joten pelkkä eteenpäin käveleminen ei väistä: pitää juosta, väistää syvyyssuunnassa tai lyödä takaisin.
- **Heitto takaa-ajajaan:** jos perässä juoksevaan tai tappelevaan (ohikulkija, punkkari, poliisi, vartija, portsari) osuu heitetty esine, hän horjahtaa taaksepäin ja pysähtyy hetkeksi: pullo 2,2 s, energiajuomatölkki 1,8 s, kahvi 1,6 s, tölkki 1,2 s, ruoka 0,9 s. Hyvä heitto antaa aikaa paeta. (Kova esine voi myös tainnuttaa kokonaan, ks. yllä.)
- **Tyrmäysten raja:** kun samaa hahmoa on tyrmätty 2–4 kertaa (raja arvotaan hahmokohtaisesti; myös heiton tainnutukset lasketaan), se jää tajuttomaksi maahan eikä enää nouse ajamaan takaa.

### Ryöstely

- Ilman lompakkoa pelaaja voi hankkia tavaraa hakkaamalla ohikulkijoita.
- Tyrmätty ohikulkija pudottaa maahan satunnaisesti alkoholia, ruokaa, rahaa tai ei mitään. Joskus se pudottaa myös avaimen tai puhelimen.
- Tyrmätty ei katoa: hetken päästä hän nousee ylös ja nilkuttaa pois korttelista. Uudelleen tyrmättynä hän ei enää pudota mitään.
- Ohikulkijoilta voi myös **taskuvarastaa** ilman tappelua.
  - Pelihahmo on **kleptomaani**: aina kun hänet ohjataan tarpeeksi lähelle jonkun selän taakse, hän yrittää **automaattisesti** näpistää tämän taskuista.
  - Joskus hän jää kiinni, joskus ei. Hiippailu (paljain jaloin) parantaa onnistumisen mahdollisuuksia.
  - Kiinni jäädessä näpistetty joko **alkaa tapella** tai **hälyttää poliisit ja/tai vartijat**.

### Poliisit ja vartijat

- Jos samalla kadulla on poliiseja tai vartijoita, ne käyvät pelaajan kimppuun, kun tämä hakkaa jotakuta.
- **Poliisit** yrittävät taltuttaa pelaajan. **Vartijat** yrittävät hakata hänet.
- Jos poliisit saavat pelaajan kiinni niin, ettei hän pääse karkuun, hän herää **putkasta**. Seuraava päivä alkaa sieltä, ja se on vaikeampi: alkoholia on hyvin vähän ja nälkä on kova.
  - **Takavarikko:** poliisi ottaa käden tavaran ja pussin, ja ne jäävät poliisiasemalle. Lompakon ja puhelimen saa vapautuessa takaisin.
    - Muut takavarikoidut tavarat voi **hakea poliisiasemalta henkilökortilla**. Ilman korttia ne jäävät sinne, kunnes kortti löytyy.
  - Ilman henkilökorttia putkassa pidetään pidempään, joten seuraava päivä alkaa myöhemmin.
  - **Sellikaveri:** putkassa on joskus joku, joka satunnaisesti joko antaa vihjeen hukatusta tavarasta tai varastaa jotain.

## Hahmot

- **Ei koskaan lapsia.**
- Hahmot ovat tuttuja kaupunkityyppejä, joille keksitään omat erikoisuudet ja käytös. Alkuperäisen tunnusomaisia hahmoja ei kopioida.
- Vähemmistöjä tai sairauksia leimaavia hahmoja ei tehdä. Jokainen hahmotyyppi käyttäytyy kuten muutkin kaupunkilaiset, eikä mikään ryhmä ole olemassa vain hakattavaksi.

Hahmoideat:

| Hahmo | Erikoisuus |
|---|---|
| Ohikulkija | voi ryöstää (ks. yllä) |
| Poliisi | taltuttaa, vie putkaan |
| Vartija | hakkaa |
| Pyöräilijä, sähköpotkulautailija | väistettävä, törmää muuten |
| Turisti / muunkielinen ohikulkija | puhuu kieltä, jota hahmo ei ymmärrä; voi kysyä tietä tai yrittää auttaa |
| Ääripuolueen edustaja | jakaa lentolehtisiä, ei pääse eroon; aatetta ei kerrota |
| Mummo | hidas, lyö käsilaukulla yllättävän kovaa |
| Lokki | varastaa ruoan kädestä |
| Kadun juoppo | voi tarjota huikan vaihtokauppana |
| Tölkinkerääjä | kilpailija pantillisista tölkeistä |
| Some-vaikuttaja | kuvaa pelaajan; video "leviää" ja poliisit tunnistavat helpommin |
| Kerjäläinen | antaa rahaa vastaan vihjeen hukatusta tavarasta |
| Punkkarit | liikkuvat aina 2–3 hengen porukassa; jos lyöt yhtä, kaikki käyvät kimppuun; jos et ärsytä, voivat tarjota tölkin kaljaa |
| Taskuvaras | satunnaisesti joko törmää ohimennen ja vie rahaa tai tavaran (esim. puhelimen; takaisin vain kiinni saamalla tai tyrmäämällä, muuten tavara hukkuu taas) tai yrittää näpistää samaan aikaan kuin pelaaja, jolloin syntyy koominen kollegakohtaus ja kumpikin saa jotain |
| Portsari | seisoo baarin ovella ja arvioi kunnon: päästää sisään vain, jos alkoholia on sopivasti; liian humalaisen tai likaisen käännyttää; ilman kenkiä ei pääse sisään; rajatapauksissa rahalahjus auttaa; väkisin tunkeva heitetään kadulle (vie healthia) |
| Pappi | auttaja: antaa joskus pullaa tai kahvia kylmissään tai nälkäiselle; paheksuu humalaa mutta auttaa silti; jos häntä lyö, poliisit tulevat erityisen nopeasti |
| Poliitikko | tavallinen vaalityyppi, satunnaisesti jompikumpi: **vaalikoju** (jakaa ilmaista kahvia ja karkkia juttelijoille; lähellä ei saa näpistää tai tapella, koska kamerat ovat paikalla ja poliisit tulevat heti) tai **kättelijä** (ryntää kättelemään eikä hänestä pääse eroon; kättelyn aikana kleptomaani näpistää automaattisesti, usein lompakon sisältöä) |
| Koira | noin **20 eri rotua**. **Irtokoira** on haistaja: seuraa pelaajaa, jos tällä on ruokaa; joskus vie ruoan, joskus johdattaa hukatun tavaran luo hajun perusteella. Irtokoira voi olla **vihainen** (hyökkää) tai **kiltti**. **Hihnassa oleva koira** on vahtikoira: haukkuu, kun pelaaja yrittää näpistää omistajalta, jolloin kiinni jäämisen riski kasvaa. **Rotu vaikuttaa käytökseen:** kokoon, nopeuteen ja siihen, kuinka todennäköisesti koira on vihainen tai kiltti (pieni koira on nopea mutta vaaraton, iso hidas mutta lyö kovaa). Pelaaja oppii tunnistamaan vaaralliset rodut ulkonäöstä |
| Muut kaupunkityypit | (lisätään myöhemmin) |

## Kuolema

- **Lööppi kuolinsyyn mukaan:** peli muistaa, mikä viimeksi vei healthia (tappelu, auto, koira, portsari, kaatuminen, kylmä, nälkä, krapula, uupumus, tai selviäminen nollaan promilleen), ja lööppiin arvotaan siihen sopiva humoristinen otsikko ja kuvateksti (2–4 vaihtoehtoa kullekin).
- **Kuva kuoleman hetkestä:** hahmo lysähtää, ja hetken päästä "lukijan kuva" otetaan eri kulmasta kuin pelikamera: katutasolta vinosti (vähän kallellaan), ylhäältä kuin ikkunasta tai tekijän olan yli. Kuva on seepiansävyinen, rakeinen ja reunoilta tumma kuin sanomalehdessä. Lööpissä on iso kuva, sen vieressä kuvateksti ja alla "Kuva: lukijan kuva".

- Kuolema esitetään **paikallislehden lööppinä**, jossa on hahmon kuva ja humoristinen otsikko kuolinsyystä, esimerkiksi "Lokki vei viimeisen makkaran – nälkä voitti". Lehden nimi on keksitty.
- Sen jälkeen näytetään **pisteet ja ennätyslista**.
  - Ennätyslista on aluksi **vain omalla laitteella**. **Yhteinen maailmanlaajuinen lista** lisätään myöhemmin; se vaatii palvelimen ja huijauksen eston.
- Uusi peli alkaa **heti napin painalluksella**, jotta tahti pysyy nopeana.

## Pisteytys

- Peli jatkuu päivästä toiseen, kunnes hahmo kuolee.
- Loppupisteet lasketaan:
  - **selvityistä päivistä** (antaa eniten pisteitä)
  - rahan määrästä
  - tavaroiden määrästä
- **Pelillä ei ole läpäisyä.** Peli jatkuu ja vaikeutuu, kunnes hahmo kuolee. Tavoitteena on selvitä mahdollisimman monta päivää ja saada parhaat pisteet.
- **Pistekaava:**
  - **Selvitty päivä:** päivän numero × 1000. Esimerkiksi päivä 5 antaa 5000 pistettä, koska myöhemmät päivät ovat vaikeampia.
  - **Raha:** 100 pistettä jokaisesta eurosta.
  - **Tavarat:** 100 pistettä jokaisesta tavarasta, joka on mukana kuollessa.
  - **Bonus:** 500 pistettä, jos pääsee kotiin ja kaikki sen päivän hukatut tavarat on löydetty.

## Pelin opettaminen

- **Saavutukset (F2):** 27 saavutusta, jotka tallentuvat laitteelle. Avautuessa vasempaan alakulmaan liukuu pokaali ja nimi. Listassa suorittamattomista näkyy vain nimi; joka kerta listan avatessa yhdestä satunnaisesta suorittamattomasta näkyy myös selitys valkoisella. Lista: Makkaramestari (tainnuta makkaroilla, kolme osumaa), Kunnon kättely, Punk's Not Dead, Ulos ja heti, Portsarin portsari, Pakotie, Pallomies, Lokkien vihollinen, Taivaan lahja, Paras ystävä, Kallis nakki, Lauma rauhoittuu, Lääkärin määräys, Raitis hetki, Vaaleanpunaiset norsut, Aamukalja, Kännissä kotiin, Kolmen kolmosen kännit (yli 3,33333 ‰), Siisti päivä, Ilman karttaa, Hyvä sydän, Painovoiman ystävä, Konepellin kyydissä, Kova ihminen, Pyykkipäivä, Lööppitähti ja Selkäsauna.

- **Ohje (F1, peliohjaimella Back):** lyhyt tavoite ja näppäimet näppäimistölle, ohjaimelle ja puhelimelle; peli odottaa ohjeen ajan. Debug-työkalut ovat piilossa: ne kytketään päälle painamalla ohjeessa F12, jonka jälkeen F5–F10 toimivat (F10 hyppää seuraavaan päivään, F11 aloittaa uuden pelin seuraavassa kaupungissa). Debugin ollessa päällä poliisien näkökeilat piirretään kadulle (punainen, kun pelaaja on keilassa).

- Erillistä opetusosiota ei ole.
- **Poikkeus: käden esineen vihje.** Kun pelaaja poimii esineen käteen, pään yläpuolelle tulee viideksi sekunniksi ikonivihje ilman tekstiä: napin kuva (näppäimistöllä välilyönti, kosketusnäytöllä iso pyöreä nappi) → toiminnon kuva (juo: kallistettu pullo, syö: makkara, lyö: nyrkki), ja alla napin kuva kellon kanssa (pidä pohjassa) → heittokaari. Tämä näkyy joka kerta.
- **Vihjeet näkyvät vain pelin ensimmäisenä päivänä**: pieniä ikonivihjeitä oikealla hetkellä, esimerkiksi oven kohdalla napin kuva ja nuoli sisään tai ensimmäisen esineen kohdalla kävelevä jalka. Kukin vihje näkyy kerran.
- Vihjeet näkyvät **jokaisen pelin ensimmäisenä päivänä**, mutta **ei uudelleen saman peli-istunnon aikana**. Jos pelaaja kuolee ja aloittaa uuden pelin sovellusta sulkematta, vihjeitä ei näytetä. Kun sovellus käynnistetään uudelleen, ne näkyvät taas.

## Kieli ja teksti

- Pelissä on **mahdollisimman vähän tekstiä**. Tapahtumat ja tilat selitetään **ikoneilla ja muodoilla**.
- Ensimmäinen kieli on **suomi**.
- Peli tehdään alusta asti **helposti lokalisoitavaksi** usealle kielelle: kaikki tekstit ovat käännöstiedostoissa (Godotin käännösjärjestelmä), eikä tekstiä kirjoiteta suoraan koodiin tai kuviin.
- Oulun kadunnimet pysyvät suomeksi kaikissa kieliversioissa.

## Tallennus

- Peli **tallentuu automaattisesti joka aamu** päivän alussa.
- Jos sovellus suljetaan kesken päivän, jatketaan **saman päivän alusta**.
- Kesken päivän ei voi tallentaa, joten huijaaminen ei onnistu.

## Tekniikka

- Pelimoottori: **Godot 4.7** (tavallinen versio, ei .NET/mono)
- Kieli: **GDScript**. Valittu, koska sillä peli voidaan viedä kaikille alustoille, myös selaimeen. Godot 4.7 ei tue C#-pelien vientiä selaimeen.
- Kohdealustat: **kaikki mahdolliset** (PC, mobiili, selain).

## Ensimmäinen prototyyppi

Tavoite: nähdä nopeasti, tuntuuko peli hyvältä, myös puhelimella. Prototyypissä on:

- **Yksi Oulun kortteli** 3D:nä (Kirkkokatu Pakkahuoneenkadun ja Hallituskadun välillä), risteykset näkymän reunoilla ja **tilt-shift-efekti**
- **Hahmo**, joka kävelee ja juoksee (kaksoisnapautus; puhelimella ohjaussauva reunaan)
- **Toimintanappi** (lyhyt: lyö / juo / syö, pitkä: heitä)
- **Muutama ohikulkija**: tappelu, tyrmäys ja pudotukset sekä automaattinen taskuvarkaus
- **Tavarat**: pullo, tölkki, makkara ja kolikot; automaattinen poiminta ja käden tavaran vaihto
- **Promillemittari** pulloikonissa, healthin sydän ja raha
- Aika kulkee vain liikkuessa; aurinko liikkuu kellon mukaan
- Kuolema lööppinä ja päivän vaihtuminen (herätään samasta korttelista)
- Kosketusohjaimet puhelimelle, näppäimistö ja peliohjain muille alustoille
- Tekstit käännöstiedostossa (suomi)

Lisätty prototyyppiin:

- **Oulun keskustan kartta:** kaikki korttelit 9 × 7 kadun ruudukossa. Korttelin päästä jatketaan seuraavaan kortteliin, ja risteyksestä käännytään ylös tai alas poikkikadulle. Kadunnimikyltit ovat risteysten kulmissa. Korttelien ulkonäkö arvotaan, mutta sama kortteli näyttää aina samalta.
- Kadulle jääneet tavarat pysyvät korttelissa saman päivän ajan. Seuraavana aamuna sisältö arvotaan uudelleen.
- Uusi peli alkaa satunnaisesta korttelista. Seuraava päivä alkaa siitä korttelista, johon hahmo nukahti.

- **Koti ja hukatut tavarat:** kodin paikka (kerrostalo, vihreä ovi) arvotaan joka peliin, ja ensimmäinen päivä alkaa kodin ovelta (myöhemmin herätään muualta). Aamulla hukatut tavarat näkyvät hahmon ajatuskuplassa ensimmäisten 5 metrin ajan ja sen jälkeen ylhäällä keskellä "Etsi:"-listassa (kun kaikki on löydetty, listan tilalle tulee sykkivä talo ja teksti "Kaikki löytyi – nyt kotiin!"); humalassa osa ikoneista muuttuu läiskiksi. Tavarat arvotaan kodin lähelle säteellä, joka kasvaa päivä päivältä. Kaukaa ne ovat harmaita möhkäleitä, ja ilman silmälaseja ne erottuvat vasta aivan läheltä. Kotiovella toimintanappi vie nukkumaan, ja kotona nukuttu yö on paras. Ilman avaimia hahmo nukkuu rappukäytävässä, ja ilman kenkiä vauhti on hitaampi. Kun kaikki tavarat löytyvät ennen kotiin menoa, saa 500 pisteen bonuksen.

- **Krapulatärinä:** erottuu kylmätärinästä: hitaampaa, epätasaista huojuntaa koko vartalossa ja välillä äkillinen nykäisy, kasvot kalpean vihertävät. Voimakkuus riippuu edellispäivän suurimmasta promillemäärästä (ensimmäisenä aamuna oletetaan rankka edellisilta) ja kasvaa, mitä selvempi hahmo on.
- **Portsari:** seisoo baarin oven vieressä. Jos portsaria lyö (tai heittää), hän lähtee perään kuin poliisi; kun hän saa pelaajan kiinni, hän nakkaa tämän niskaperseotteella kadulle (10 healthia), ja palaa sitten ovelle. Hän luovuttaa, jos pelaaja pääsee tarpeeksi kauas, eikä seuraa toiseen kortteliin. Tyrmättynä hän nousee ja palaa ovelle.
- **Katuhahmot:** osassa kortteleita on lisäksi
  - **kerjäläinen**, joka istuu seinän vieressä paperikuppi edessään: viereen mennessä näkyy napin kuva → kolikko → "?", ja 2 eurolla hän kertoo, millä kadulla jokin hukattu tavara on (kerran)
  - **kadun juoppo**, joka huojuu pullo kädessä: 1 eurolla tai kädessä olevalla ruoalla saa huikan (+0,3 ‰, kahdesti)
  - **punkkariporukka** (2–3, toisesta päivästä alkaen; nahkatakit ja värikkäät irokeesit): lyö yhtä, niin kaikki käyvät kimppuun; ensimmäisellä kohtaamisella he saattavat antaa tölkin kaljaa
  - **punkkarin pillerit:** tyrmätty punkkari pudottaa (kerran) pussin vaaleanpunaisia ja sinisiä pillereitä. Pussi otetaan käteen ja syödään kuten ruoka. Pelaaja menee kunnolla sekaisin: humala nousee paljon (+1,2 ‰, imeytyy kuten juoma; sammumisraja voi tulla vastaan), ja noin minuutin ajan (pelin aikaa) hän näkee näkyjä: ruudun yli aaltoilee sateenkaaren värejä ja renkaita, ja kadulle ilmestyy leijuvia, hehkuvia hallusinaatioita (siivekkäitä vaaleanpunaisia norsuja, jättisieniä, silmiä ja pyöriviä spiraaleja), jotka häipyvät hetken päästä.
  - **lokkeja**, jotka nokkivat maassa ja pyrähtävät pois juoksevan tieltä; jos kädessä on ruokaa, lokki lentää nappaamaan sen, ellei sitä ehdi huitaista pois lyönnillä
  - **lokin päälle astuminen:** jos pelaaja kävelee maassa olevan lokin yli, siitä pöllähtää höyheniä ja se lentää pois. Hetken päästä korttelin muut lokit (tai pari reunan takaa saapuvaa) kiertelevät aivan pelaajan yläpuolella noin 12 sekuntia ja pudottavat paskaa 1–2 sekunnin välein, tähdäten sinne, missä pelaajan pää on pudotuksen osuessa (liikkuessakin). Osuma jättää näkökenttään valkoisen läiskän, joka haihtuu pikkuhiljaa (noin 7 s); ohi menneet jäävät hetkeksi valkoisiksi täpliksi katuun.
  - **irtokoira** (kuusi rotua: chihuahua, terrieri, labradori, husky, paimenkoira ja rottweiler; koko, nopeus, luonne ja purennan voima rodun mukaan; vihaisella koiralla on pystyssä olevat niskakarvat ja jäykkä häntä). Kiltti koira seuraa ruokaa kantavaa ja välillä nappaa sen; joskus se haistaa korttelissa olevan hukatun tavaran ja johdattaa sen luo haukkuen. Vihainen koira hyökkää ja puree. Puraisun jälkeen se perääntyy pari askelta ja haukkuu 1,5–3 sekuntia ennen kuin hyökkää uudestaan (ei aina täydellä vauhdilla eikä suoraan). Lyönti saa sen perääntymään ja tarpeeksi monesta se lähtee vinkuen. Koirasta pääsee eroon heittämällä makkaran (se menee syömään ja rauhoittuu) tai osumalla siihen heitetyllä esineellä (se lähtee vinkuen karkuun). Heitetty esine ajaa myös lokin pois.
- **Ilman puhelinta ei olla hukassa:**
  - Puhelin itse hukkuu aina lähelle päivän aloituspaikkaa (noin korttelin päähän), joten sen löytäminen on helppo alku.
  - "Etsi:"-listan tavaroiden takana hehkuu aina (puhelimen kanssa tai ilman) "kuuma–kylmä"-valo, kun tavara on enintään noin kahden korttelin päässä: mitä lähempänä, sitä lämpimämpi väri ja nopeampi syke.
  - Kerjäläisiä on silloin kaksi kertaa useammin.
- **Koti:** kodin korttelissa oven yllä kelluu sykkivä vihreä talo ja teksti "Koti". Kun pelaaja tulee lähelle ensimmäisen kerran päivässä, ruudun keskelle ponnahtaa "Löysit kotiin!" (ei silloin, kun päivä alkaa kotiovelta, vaan vasta kun on ensin käynyt kauempana). Kadun puolelta nuoli osoittaa ovelle, ja aivan oven vieressä näkyy napin kuva → sänky.
- **Selitys pelin alussa:** kaupungin nimen alla neljä lyhyttä riviä kuvakkeineen: tavarat hukkuivat yöllä – etsi ne; lämpömittari kertoo, kuinka lähellä tavara on; juo sopivasti (selvänä kuolet, liikaa juotuasi sammut); lopuksi kotiin nukkumaan. Häipyvät, kun hahmo liikkuu.
- **Lämpömittari:** "Etsi:"-listan jokaisen puuttuvan tavaran alla on mittari (sininen = kaukana, punainen = lähellä), ja listan lopussa sana lähimmän puuttuvan mukaan: Kylmä (yli 2 korttelia), Haalea, Lämmin, Kuuma (samassa korttelissa) ja Polttaa! (aivan vieressä). Samassa korttelissa lämpö kasvaa metrien mukaan.
- **Hukattu tavara maassa:** lähellä (noin 4 m, ilman silmälaseja 1,6 m) tavara saa värinsä, pyörii ja hyppii, sen ympärillä sykkii hehkuva keltainen rengas, ja yllä pomppii nuoli.
- **Reunanuoli:** jos hukattu tavara on samassa korttelissa mutta ruudun ulkopuolella, ruudun reunassa näkyy oranssi nuoli ja tavaran kuva siihen suuntaan.
- **Löytö:** kun hukattu tavara löytyy, sen kuva ponnahtaa isona keskelle ruutua valkoiselle pohjalle säteiden ja vihreän rastin kanssa ja liukuu sitten ylös "Etsi:"-listaan.
- **Tuulessa lentävät lehdet:** kaduilla on syksyn lehtiä (ei lumella). Tuulella on hitaasti vaihteleva perussuunta ja välillä puuskia. Maassa makaavat lehdet liukuvat nykien ja kääntyilevät tuulen voimistuessa ja nousevat ilmaan kovassa puuskassa. Ilmassa lehti putoaa hitaasti heilurimaisesti puolelta toiselle (hidastuu heilahduksen päissä ja kallistuu sen mukana) ja pyörii kovassa tuulessa. Välillä tuuli nappaa lehden niin, että se kiepsahtaa kerran ympäri ja tekee samalla pienen silmukan ilmassa (kovassa tuulessa useammin). Välillä puuska nostaa pienen kasan lehtiä yhdessä pyörteeksi. Ohi ajava auto vetää ilmaa mukanaan: lähellä auton kylkeä ja sen perässä lehdet pöllähtävät liikkeelle ja ilmaan auton kulkusuuntaan. Sateella lehdet ovat märkiä ja raskaita. Lehdet liikkuvat vain, kun pelin aika kulkee.
- **Sää:** joka päivä arvotaan aurinkoinen (liikkuvat pilvien varjot), pilvinen (pehmeä valo), sade (pisarat, harmaa valo, sumu) tai lumi ja pakkanen (hiutaleet, lumikerros kaduilla, reunakiven yli tai esteeseen törmätessä voi liukastua, kengättä helpommin). Sade ja lumi pysähtyvät ilmaan, kun aika on pysähdyksissä.
- **Lumi on liukas:** lumisateella hahmo liukuu napin päästämisen jälkeen (selvin päin noin 0,3 s, humalassa pidempään: 0,3 s + 0,5 s jokaista promillea kohti) ja kääntyy laiskasti; liu'un aikana aika kulkee. Yli 1,1 promillessa jyrkkä käännös voi kaataa hahmon perseelleen: suoraan kävellessä tuskin koskaan, todennäköisyys kasvaa käännöksen jyrkkyyden mukaan ja on suurin, kun kääntyy yhtäkkiä vastakkaiseen suuntaan (humala, juoksu ja kengättömyys lisäävät).
- **Kylmä:** ei mittaria; hahmo tärisee, kun on kylmissään: nopea, pieni värinä, kädet halaavat vartaloa, kasvot sinertävät ja suusta nousee höyryä. Kylmä kasvaa sateella ja pakkasella, ilman takkia ja märillä/kylmillä jaloilla nopeammin; aurinkoisella säällä hahmo lämpenee. Kylmissään nälkä kasvaa 1,5-kertaisesti, ja kova kylmä kuluttaa healthia. Humalassa (yli 1,3 ‰) kylmä tuntuu vähemmän. Kioskissa ja baarissa lämpenee, mutta aika kuluu sillä aikaa. **Kylmissään voi myös lämmitellä:** juokseminen lämmittää (kylmä vähenee juostessa, myös sateella ja pakkasella), jokainen lyönti lämmittää vähän, ja tiukka viina lämmittää heti (viina paljon, tuntematon aine melkein yhtä paljon, tavallinen pullo vähän, olut ei lainkaan). Aamun kylmyys riippuu yöpaikasta.

- **Kotityypit:** kerrostaloasunto (ilman avaimia rappukäytävä), kellarikomero (ilman avaimia riippulukko rikotaan kolmella lyönnillä; kylmä yö) ja kaverin sohva (ovikello; juoma kädessä pääsee aina sisään, muuten kaveri nukkuu joskus eikä avaa sinä päivänä).
- **Tavaroiden haitat:** ilman silmälaseja kadunnimikyltit ovat sumeita (humalassa kirjaimet myös menevät sekaisin), ilman aurinkolaseja aurinko häikäisee aurinkoisella säällä, ilman takkia lyönnit sattuvat 30 % enemmän ja paljain jaloin taskuvarkaus onnistuu paremmin.

- **Puhelin:** oma puhelinnappi avaa ja sulkee, vasen/oikea selaa. Viestit (tavaran ikoni ja kadunnimen alku), eilinen kuva (katukyltti ja hukattu tavara, hahmon edessä "sattumalta" sumea esine) ja kartta (pohjoinen ylhäällä, oma sijainti ja kulkusuunta (sininen nuoli ja näkökeila), koti sekä vihjeet: oranssina sykkivä korttelinpätkä (katu kahden risteyksen välillä), jolla hukattu tavara on, ja tavaran ikoni sen keskellä; tarkka kohta ja kadun puoli jäävät etsittäviksi; vihje näkyy kaikille hukatuille tavaroille (puhelinta lukuun ottamatta), ja se katoaa, kun tavara löytyy). Ensimmäisenä päivänä akkua on 50 %, jotta pelaaja voi katsoa kartalta, missä on; myöhempinä aamuina akkua on vähän (8–25 %). Akku kuluu reaaliajassa vain puhelimen ollessa auki (viestit 0,15 %/s, kuva 0,225 %/s, kartta 0,45 %/s); kartta kuluttaa eniten. Maailma on pysähdyksissä puhelimen ollessa auki.
- **Kioski ja baari:** joissain kortteleissa (valaistu ovi ja kyltti), auki tai kiinni päivästä riippuen. Kioskista pullo (3 €), makkara (2 €) ja puhelimen lataus (ilmainen, mutta aika harppaa ja promillet laskevat). Baarissa tuoppi (5 €), ja ovella on portsari. Ostaminen vaatii lompakon ja alkoholi henkilökortin.
- **Nälkä:** kasvaa liikkuessa ja yöllä, kova nälkä kuluttaa healthia ja tyhjään mahaan alkoholi nousee 40 % enemmän. Ei mittaria: hahmosta nousee välillä vatsan kuva (maha kurisee), ja hahmo lysähtää. Makkara vie nälkää.

- **Takaa-ajajat seuraavat seuraavalle kadulle:** perässä juoksevat poliisit, vartijat ja tappelevat ohikulkijat seuraavat pelaajaa, kun tämä vaihtaa korttelia tai kääntyy risteyksestä, mutta ne ilmestyvät noin 4 metriä kauemmas kuin ne olivat. Kadun vaihtaminen antaa siis pienen etumatkan.
- **Poliisit ja vartijat:** poliiseja partioi osassa kortteleita (todennäköisyys kasvaa päivä päivältä, myöhemmin joskus pareittain), vartijoita seisoo kauppojen lähellä. Kun pelaaja lyö jotakuta tai heittää jollekulle pullon, korttelin vartijat käyvät kimppuun. **Poliisilla on näkökenttä:** poliisi huomaa rikoksen vain, jos pelaaja on keilassa sen kasvojen edessä (±50°, 16 m; aivan vieressä, alle 1,5 m, poliisi huomaa joka suuntaan). Keila ei näy pelaajalle. Rikoksia ovat tappelu (ihmisen lyöminen tai esineen heittäminen ihmiseen) sekä eläimen (lokki, koira) lyöminen tai heittäminen; eläimistä välittävät vain poliisit. Kävellessään poliisi kääntää välillä päätään 1–2 sekunniksi katsoakseen kadun toiselle puolelle. Epäonnistuneen taskuvarkauden uhri joko tappelee tai huutaa apua; huudon poliisi kuulee katsomatta, ja poliisi voi myös juosta paikalle korttelin päästä. Paljain jaloin vartijat huomaavat rikoksen vain läheltä (7 m) ja poliisin keila on vain 7 m pitkä; humalassa (yli 1,3 ‰) matka on hiippaillessa kaksinkertainen ja muuten poliisin keila 1,25-kertainen. Poliisin lyöminen vain horjuttaa hetkeksi. Kun poliisi pysyy pelaajan vieressä, ruudulle täyttyy sini-punainen rengas; täynnä oleva rengas vie putkaan. Toiseen kortteliin juoksemalla tai karkaamalla kauas pääsee pakoon.
- **Putka ja poliisiasema:** poliisiasema on Isokadulla Pakkahuoneenkadun ja Hallituskadun välissä (POLIISI-kyltti). Putkayön jälkeen herätään aseman ovelta: alkoholia 0,3 ‰ ja kova nälkä. Käden tavara takavarikoidaan; sen saa takaisin aseman ovelta henkilökortilla. Ilman henkilökorttia herätään kaksi tuntia myöhemmin. Sellikaveri joko kertoo, millä kadulla jokin hukattu tavara on, tai vie puolet rahoista.

- **Väsymys:** kasvaa liikkuessa, juostessa ja illalla pimeällä nopeammin (klo 20 jälkeen kaksinkertaisesti, klo 22 jälkeen kolminkertaisesti). Ei mittaria: silmät painuvat kiinni, hahmo lysähtää ja päästä nousee välillä Zzz. Täynnä hahmo nukahtaa siihen paikkaan. Aamulla väsymys on lähes nolla (kotona 0, kaverilla 5, muualla 15).
- **Kahvi ja energiajuoma:** löytyvät harvoin kadulta; energiajuomaa saa kioskista (3 €). Kahvi vie väsymystä 35, energiajuoma 45. Kaksi kofeiinijuomaa lyhyessä ajassa saa hahmon tärisemään 20 sekunniksi, jolloin lyönnit menevät usein ohi.

- **Fysiikka (rätkänukke):** kaatumisissa ja osumissa hahmo muuttuu hetkeksi fysiikalla liikkuvaksi rätkänukeksi (raajat nivelillä), joka lentää, pyörii ja lysähtää maahan; sen jälkeen hahmo nousee siitä, mihin päätyi. Koskee pelaajaa (auton töytäisy ja yliajo, kompastuminen, liukastuminen) ja ohikulkijoita, poliiseja ja vartijoita (tyrmäys, auton alle jääminen). Nivelillä on rajat, joten raajat eivät käänny vääriin suuntiin (lonkka: eteen 100°, taakse 30°, sivulle 20°; olkapää: eteen/ylös 170°, taakse 45°, sivulle 70°; vähän kiertoa). Pää on kiinni vartalossa. Kävely ja ohjaus pysyvät tavallisina. Fysiikka pysähtyy, kun pelin aika pysähtyy. Fysiikkamoottori on Jolt.

Prototyypistä puuttuu vielä muun muassa hukatut tavarat, puhelin, nälkä, kylmä, väsymys, sää, poliisit ja muut hahmotyypit sekä sisätilat.

## Avoimet kysymykset

- Hukattujen tavaroiden haittavaikutukset
- Hahmojen erikoisuudet tarkemmin
- Lisää rakennuksia ja sisätiloja myöhemmin (aloituslista on päätetty)
