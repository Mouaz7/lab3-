# Input/Output Library for x64 Assembly
.data
    .equ    BUFF_SIZE, 1024          # Storlek på buffertarna (1024 tecken)
    inBuf:  .space  BUFF_SIZE        # Lagrar input från användaren (t.ex. text från tangentbordet)
    outBuf: .space  BUFF_SIZE        # Lagrar output som ska skrivas till skärmen
    inPos:  .quad   0                # Nuvarande position i input-bufferten (vi börjar på position 0)
    outPos: .quad   0                # Nuvarande position i output-bufferten
    inSize: .quad   0                # Hur många tecken som finns i input-bufferten just nu
.text
    # Importera C-funktioner som används i koden
    .extern fgets                                   #Läser en rad text från stdin (tangentbord)
    .extern puts                                    #Skriver en textsträng till stdout (skärm)
    .extern stdin                                   #Pekare till standard input (t.ex. tangentbord)
    .extern stdout                                  #Pekare till standard output (t.ex. skärm)

    # Exportera alla funktioner så de kan användas i andra filer
    .global inImage                                               #Laddar input till input-bufferten
    .global getInt                                                #Läser ett heltal från input
    .global getText                                               #Läser en textsträng från input
    .global getChar                                               #Läser ett enskilt tecken från input
    .global getInPos                                              #Returnerar nuvarande position i input-bufferten
    .global setInPos                                              #Ändrar positionen i input-bufferten
    .global outImage                                              #Skriver output-bufferten till skärmen
    .global putInt                                                #Skriver ett heltal till output-bufferten
    .global putText                                               #Skriver en textsträng till output-bufferten
    .global putChar                                               #Skriver ett tecken till output-bufferten
    .global getOutPos                                             #Returnerar nuvarande position i output-bufferten
    .global setOutPos                                             #Ändrar positionen i output-bufferten

# Funktionsstubbar - ska implementeras
inImage:
    pushq   %rbp            # Sparar gamla baspekaren på stacken
    movq    %rsp, %rbp      # Sätter ny baspekare för denna funktion

    #Anropar fgets för att läsa input från tangentbordet
    movq    $inBuf, %rdi    # Första argument: adress till input-bufferten
    movq    $BUFF_SIZE, %rsi # Andra argument: max antal tecken att läsa (1024)
    movq    stdin(%rip), %rdx #  Tredje argument: pekare till standard input (tangentbord)
    call    fgets           # Läser en rad text och sparar i inBuf

    # Räknar hur lång den inlästa texten är
    movq    $0, inPos(%rip) # Nollställer input-positionen (börja från början av bufferten)

    # Räknar hur lång den inlästa texten är:
    movq    $0, %rcx        # Startar en räknare på 0
count_loop:
    cmpb    $0, inBuf(%rcx) #Kollar om tecknet på position %rcx är 0 (slut på texten)
    je      done_counting   # Om ja: hoppa till done_counting
    incq    %rcx            # Öka räknaren med 1
    jmp     count_loop      # Fortsätt loopa tills slut på texten

done_counting:
    movq    %rcx, inSize(%rip) # Sparar textens längd i inSize

    movq    %rbp, %rsp      # Återställ stackpekaren
    popq    %rbp            # Återställ baspekaren
    ret                     # Avsluta funktionen

getInt:
    pushq   %rbp            # Sparar gamla baspekaren
    movq    %rsp, %rbp      # Ny baspekare
    pushq   %rbx            # Sparar %rbx (kommer användas för att lagra talet)

    # Kollar om vi har läst alla tecken i bufferten
    movq    inPos(%rip), %rax  # Hämtar nuvarande position i input
    cmpq    inSize(%rip), %rax # Jämför med totala längden
    jge     getInt_need_input  # Om slut på data: ladda ny input

getInt_continue:
    movq    $0, %rbx        # Nollställ resultatet (här byggs talet)
    movq    $1, %r8         # Sign-variabel (1 = positivt, -1 = negativt)

    # Hoppar över mellanslag/radbrytningar:
getInt_skip_space:
    movq    inPos(%rip), %rax       # Nuvarande position
    cmpq    inSize(%rip), %rax      # Är positionen längre än texten?
    jge     getInt_need_input       # Om ja: ladda ny input

    movb    inBuf(%rax), %cl #Hämtar tecknet från bufferten
    cmpb    $32, %cl         # Mellanslag (ASCII 32)
    je      getInt_next_space # Hoppa över
    cmpb    $9, %cl          # Tabb (ASCII 9)
    je      getInt_next_space
    cmpb    $10, %cl         # Radbrytning (ASCII 10)
    je      getInt_next_space
    jmp     getInt_check_sign # Annars: kolla om det är ett tecken (+/-)

getInt_next_space:
    incq    inPos(%rip)       # Annars: kolla om det är ett tecken (+/-)
    jmp     getInt_skip_space # Fortsätt hoppa över mellanslag

    # Kollar om talet är negativt/positivt
getInt_check_sign:
    movq    inPos(%rip), %rax  #  Hämtar tecknet igen
    movb    inBuf(%rax), %cl   #

    cmpb    $43, %cl        #'+' (ASCII 43)
    je      getInt_plus
    cmpb    $45, %cl        # '-' (ASCII 45)
    je      getInt_minus
    jmp     getInt_digits   # Om inget tecken: börja läsa siffror

getInt_plus:
    incq    inPos(%rip)     # Hoppa över '+' tecknet
    jmp     getInt_digits

getInt_minus:
    movq    $-1, %r8        # Sätt sign-variabeln till -1
    incq    inPos(%rip)     # Hoppa över '-' tecknet

    # Läser siffrorna och bygger talet
getInt_digits:
    movq    inPos(%rip), %rax     # Nuvarande position
    cmpq    inSize(%rip), %rax    # Är vi vid slutet av bufferten?
    jge     getInt_done           # Avsluta om ja

    movb    inBuf(%rax), %cl      # Hämtar nästa tecken

    # Check if character is a digit
    subb    $48, %cl        # Konverterar ASCII-siffra till tal (t.ex. '5' -> 5)
    cmpb    $0, %cl         # Är tecknet mindre än 0? (ogiltig siffra)
    jl      getInt_done
    cmpb    $9, %cl         # Är tecknet större än 9? (ogiltig siffra)
    jg      getInt_done

    # Uppdaterar resultatet: resultat = resultat * 10 + ny_siffra
    movq    %rbx, %rax
    imulq   $10, %rax       #Multiplicera nuvarande resultat med 10
    movzbq  %cl, %rcx       #Konverterar till 64-bitars tal
    addq    %rcx, %rax      #Lägg till den nya siffran
    movq    %rax, %rbx

    incq    inPos(%rip)     # Flytta till nästa tecken
    jmp     getInt_digits   # Fortsätt läsa siffror

getInt_done:
    # Applicerar sign (positivt/negativt)
    movq    %rbx, %rax
    imulq   %r8, %rax       # Multiplicera med tecken

    popq    %rbx            # Återställ %rbx
    movq    %rbp, %rsp      # Återställ stackpekaren
    popq    %rbp
    ret

getInt_need_input:
    call    inImage         # Ladda ny input till bufferten
    jmp     getInt_continue # Fortsätt läsa tal

getText:
    pushq   %rbp
    movq    %rsp, %rbp
    pushq   %rbx            # Sparar %rbx (används för buffertadressen)

    # Sparar parametrar
    movq    %rdi, %rbx      # Första argument: adress till mål-bufferten
    movq    %rsi, %r8       # Andra argument: max antal tecken att läsa

    # Kollar om vi behöver ny input
    movq    inPos(%rip), %rax
    cmpq    inSize(%rip), %rax
    jge     getText_need_input

getText_continue:
    movq    $0, %rcx        # Räknare för antal lästa tecken

getText_loop:
    # Kollar om vi har nått max längd-1 (för att lämna plats för null)
    movq    %r8, %rdx
    decq    %rdx            # Max längd - 1
    cmpq    %rdx, %rcx
    jge     getText_done    # Avsluta om fullt

    # Kollar om vi är vid slutet av input
    movq    inPos(%rip), %rax
    cmpq    inSize(%rip), %rax
    jge     getText_done

    # Hämtar tecknet från input-bufferten
    movb    inBuf(%rax), %dl

    # Stanna vid nylinjen
    cmpb    $10, %dl     # Är tecknet en radbrytning?
    je      getText_done # Avsluta om ja

    # Sparar tecknet i mål-bufferten
    movb    %dl, (%rbx, %rcx) # Mål-buffert[rcx] = tecken

    # Increment positions
    incq    inPos(%rip)  # Öka input-positionen
    incq    %rcx         # Öka räknaren
    jmp     getText_loop # Fortsätt loopa

getText_done:
    # NULL avsluta strängen
    movb    $0, (%rbx, %rcx)

    # Returvärde: antal lästa tecken
    movq    %rcx, %rax

    popq    %rbx            # Återställ %rbx
    movq    %rbp, %rsp
    popq    %rbp
    ret

getText_need_input:
    call    inImage     #Ladda ny input
    jmp     getText_continue

getChar:
    pushq   %rbp
    movq    %rsp, %rbp

    # Hämtar tecknet från input-bufferten
    movq    inPos(%rip), %rax
    cmpq    inSize(%rip), %rax
    jge     need_input      # If position >= size, get new input

continue_getchar:
    # Get character at current position
    movq    inPos(%rip), %rax
    movb    inBuf(%rax), %al    # Sparar tecknet i %al

    # Increment position
    incq    inPos(%rip)         # Flytta till nästa tecken

    movq    %rbp, %rsp
    popq    %rbp
    ret

need_input:
    call    inImage              # Ladda ny input
    jmp     continue_getchar

getInPos:
    pushq   %rbp
    movq    %rsp, %rbp

    # Hämtar positionen och returnerar i %rax
    movq    inPos(%rip), %rax

    movq    %rbp, %rsp
    popq    %rbp
    ret

setInPos:
    pushq   %rbp
    movq    %rsp, %rbp

    # Hämtar önskad position (första argumentet)
    movq    %rdi, %rax

    #Kollar om positionen är ogiltig
    cmpq    $0, %rax      # Är positionen < 0?
    jl      setInPos_zero # Sätt till 0

    # If position > MAXPOS (inSize), set to MAXPOS
    cmpq    inSize(%rip), %rax   # Är positionen > inSize?
    jg      setInPos_max         # Sätt till inSize

    # Sparar giltig position
    movq    %rax, inPos(%rip)
    jmp     setInPos_done

setInPos_zero:
    movq    $0, inPos(%rip)   # Sätter positionen till 0
    jmp     setInPos_done

setInPos_max:
    movq    inSize(%rip), %rax  # Sätter positionen till sista tecknet
    movq    %rax, inPos(%rip)

setInPos_done:
    movq    %rbp, %rsp
    popq    %rbp
    ret

outImage:
    pushq   %rbp
    movq    %rsp, %rbp

    # Null-avslutar output-bufferten
    movq    outPos(%rip), %rax
    movb    $0, outBuf(%rax)   # Sätter 0 vid nuvarande position

    # Anropar puts för att skriva bufferten till skärmen
    movq    $outBuf, %rdi   # Argument: adress till outBuf
    call    puts            # Skriv ut strängen

    # Nollställer output-positionen
    movq    $0, outPos(%rip)

    movq    %rbp, %rsp
    popq    %rbp
    ret

putInt:
    pushq   %rbp
    movq    %rsp, %rbp
    pushq   %rbx            # Sparar %rbx
    subq    $32, %rsp       # Skapar temporär buffert på stacken

    # Förbereder talet
    movq    %rdi, %rbx      # Sparar talet i %rbx
    movq    %rsp, %r8       # Adress till temporär buffert
    addq    $31, %r8        # Börjar skriva bakifrån i bufferten
    movb    $0, (%r8)       # Null-avslutar bufferten
    decq    %r8

    # Hanterar negativa tal
    movq    %rbx, %rax
    movq    $0, %r9         # Sign-flagga (0 = positivt)
    cmpq    $0, %rax
    jge     putInt_convert
    negq    %rax            # Gör talet positivt
    movq    $1, %r9         # Sätter flaggan till negativt

putInt_convert:
    # Konverterar talet till sträng (baklänges)
    movq    $10, %rcx # Dividerar med 10

putInt_loop:
    movq    $0, %rdx        # Nollställer %rdx för division
    divq    %rcx            # Delar %rax med 10, rest i %rdx
    addb    $48, %dl        # Konverterar siffra till ASCII
    movb    %dl, (%r8)      # Sparar siffran i bufferten
    decq    %r8             # Flyttar pekaren bakåt

    cmpq    $0, %rax        # Kollar om talet är 0
    jne     putInt_loop     # Fortsätt om inte klart

    #Lägger till minustecken om negativt
    cmpq    $1, %r9
    jne     putInt_output
    movb    $45, (%r8)      #  Lägger till '-'
    decq    %r8

putInt_output:
    # Peka på första tecknet
    incq    %r8  # Flyttar pekaren till början av strängen

    # Kopierar strängen till output-bufferten
putInt_copy:
    movb    (%r8), %al      # Hämtar tecken från temporär buffert
    cmpb    $0, %al         # Är det slut på strängen?
    je      putInt_done

    # Kollar om output-bufferten är full
    movq    outPos(%rip), %rcx
    cmpq    $BUFF_SIZE, %rcx
    jge     putInt_flush        # Töm bufferten om full

    # Sparar tecknet i output-bufferten
    movb    %al, outBuf(%rcx)
    incq    outPos(%rip)
    incq    %r8             #Nästa tecken
    jmp     putInt_copy

putInt_flush:
    pushq   %r8
    call    outImage        # Skriv ut bufferten
    popq    %r8
    jmp     putInt_copy     # Fortsätt kopiera

putInt_done:
    # Städa upp och lämna tillbaka
    addq    $32, %rsp       #Rensa temporär buffert
    popq    %rbx
    movq    %rbp, %rsp
    popq    %rbp
    ret

putText:
    pushq   %rbp            # Sparar gamla baspekaren
    movq    %rsp, %rbp      # Sätter ny baspekare
    pushq   %rbx            # Sparar %rbx (används för strängadressen)

    # Sparar adressen till textsträngen (första argumentet)
    movq    %rdi, %rbx

putText_loop:
    # Kontrollera om vi har nått slutet av strängen
    movb    (%rbx), %al     # Hämtar ett tecken från strängen
    cmpb    $0, %al         # Är tecknet en null (slut på strängen)?
    je      putText_newline # Hoppa till att lägga till radbrytning

    # Kollar om output-bufferten är full
    movq    outPos(%rip), %rcx      # Hämtar nuvarande position i output
    cmpq    $BUFF_SIZE, %rcx        # Jämför med max storlek
    jge     putText_flush           # Om full: töm bufferten

putText_continue:
    # Kopiera tecken till utdatabuffert
    movb    %al, outBuf(%rcx) # Sparar tecknet i output-bufferten

    # Increment positions
    incq    %rbx            # Flyttar till nästa tecken i strängen
    incq    outPos(%rip)    # Ökar positionen i output-bufferten
    jmp     putText_loop    # Fortsätter loopen

putText_flush:
    # Spara aktuell karaktär
    pushq   %rax    # Sparar aktuellt tecken på stacken

    call    outImage # Tömmer bufferten (skriver till skärmen)

    # Återställ karaktär
    popq    %rax               # Hämtar tillbaka tecknet från stacken
    jmp     putText_continue   # Fortsätter efter att ha tömt bufferten

putText_newline:
    # Lägger till en radbrytning (ASCII 10) i output
    movq    outPos(%rip), %rcx    # Hämtar output-positionen
    cmpq    $BUFF_SIZE, %rcx      # Kollar om bufferten är full
    jge     putText_flush_newline # Om full: töm bufferten först
    movb    $10, outBuf(%rcx)     # Lägger till radbrytningstecken
    incq    outPos(%rip)          # Ökar positionen

putText_done:
    popq    %rbx        # Återställer %rbx
    movq    %rbp, %rsp  # Återställer stackpekaren
    popq    %rbp        # Återställer baspekaren
    ret                 # Avslutar funktionen

putText_flush_newline:
    call    outImage        # Tömmer bufferten
    jmp     putText_newline # Försöker lägga till radbrytning igen

putChar:
    pushq   %rbp        # Sparar gamla baspekaren
    movq    %rsp, %rbp  # Sätter ny baspekare

    # Kollar om output-bufferten är full
    movq    outPos(%rip), %rax  # Hämtar nuvarande position
    cmpq    $BUFF_SIZE, %rax    # Jämför med max storlek
    jge     putChar_flush       # Om full: töm bufferten

putChar_continue:
    # Hämta tecken från parameter (rdi)
    movb    %dil, outBuf(%rax) # Sparar tecknet (från %dil) i bufferten

    # Öka position
    incq    outPos(%rip)

    movq    %rbp, %rsp #  Återställer stackpekaren
    popq    %rbp       #  Återställer baspekaren
    ret                #  Avslutar funktionen

putChar_flush:
    call    outImage        # Tömmer bufferten
    jmp     putChar_continue # Försöker spara tecknet igen

getOutPos:
    pushq   %rbp        # Sparar gamla baspekaren
    movq    %rsp, %rbp  # Sätter ny baspekare

    # Hämtar output-positionen och returnerar i %rax
    movq    outPos(%rip), %rax

    movq    %rbp, %rsp   #   Återställer stackpekaren
    popq    %rbp         #   Återställer baspekaren
    ret                  #   Avslutar funktionen

setOutPos:
    pushq   %rbp        # Sparar gamla baspekaren
    movq    %rsp, %rbp  # Sätter ny baspekare

    # Hämtar önskad position (första argumentet)
    movq    %rdi, %rax

    # Kollar om positionen är ogiltig
    cmpq    $0, %rax        # Är positionen < 0?
    jl      setOutPos_zero  # Sätt till 0

    #  Är positionen > buffertstorlek?
    cmpq    $BUFF_SIZE, %rax
    jg      setOutPos_max    # Sätt till max storlek

    # Sparar giltig position
    movq    %rax, outPos(%rip)
    jmp     setOutPos_done # Hoppar över felhantering

setOutPos_zero:
    movq    $0, outPos(%rip)    # Nollställer positionen
    jmp     setOutPos_done

setOutPos_max:
    movq    $BUFF_SIZE, %rax    # Sätter positionen till buffertens slut
    movq    %rax, outPos(%rip)

setOutPos_done:
    movq    %rbp, %rsp  # Återställer stackpekaren
    popq    %rbp        # Återställer baspekaren
    ret                 # Avslutar funktionen
