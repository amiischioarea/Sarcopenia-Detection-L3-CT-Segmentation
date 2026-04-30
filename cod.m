clc
clear all
close all

% felia - unitate de baza a imaginii ct
% etapa 1: organizarea datelor
% definirea caii catre folderul cu imagini axiale
% deschide o fereastra pentru a alege manual folderul 
caleDate = uigetdir('C:\Users\User\OneDrive - Technical University of Cluj-Napoca\Desktop\sarcopenia\Baza de date CT sarcopenie', 'selecteaza pacientul');

if caleDate == 0
    error('nu ati selectat niciun folder');
end

% citirea listei de fisiere DICOM 
fisiere = dir(fullfile(caleDate, '*.dcm'));

% selectia unei felii in mijlocul setului 
idxMijloc = round(length(fisiere)/2); 
numeFisier = fullfile(caleDate, fisiere(idxMijloc).name);

% citirea datelor si a imaginii brute
info = dicominfo(numeFisier);
imgRaw = double(dicomread(info)); % convertim in 'double' 

% afisarea datelor tehnice extrase - pt documentatie
fprintf('--- REZULTATE ETAPA 1: %s ---\n', info.PatientName.FamilyName);
fprintf('numar total felii: %d\n', length(fisiere));
fprintf('dimensiune pixel (PixelSpacing): %.4f mm\n', info.PixelSpacing(1));
fprintf('grosime felie (SliceThickness): %.2f mm\n\n', info.SliceThickness);

% vizualizare
figure;
imshow(imgRaw, []);
title('imagine CT axiala - etapa 1');

% etapa 2: preprocesarea imaginilor (conversie HU și Windowing)
% conversia in unitati Hounsfield (HU)
% formula transforma valorile brute ale pixelilor în densitati reale
%y = ax+b
imgHU = imgRaw * info.RescaleSlope + info.RescaleIntercept;  

% windowing - filtrarea densitătii pentru muschi
% standard medical pentru muschi scheletic: [-29, +150] HU
limitaInf = -29; 
limitaSup = 150;

% se creeaza imaginea filtrata pentru segmentare
imgFiltrata = imgHU;
imgFiltrata(imgHU < limitaInf) = limitaInf;
imgFiltrata(imgHU > limitaSup) = limitaSup;

% elimina pixelii izolati (zgomotul) pt a clarifica muschiul
% se ia un patrat de 3x3 pixeli
imgFinala = medfilt2(imgFiltrata, [3 3]);

% vizualizare
figure;
imshow(imgFinala, [limitaInf limitaSup]);
title('imagine CT axiala - etapa 2');

% vizualizare rezultate e1 vs e2
figure('Name', 'Etapa 1 vs Etapa 2', 'NumberTitle', 'off');

% imagine bruta (e1)
subplot(1, 2, 1);
imshow(imgRaw, []);
title('etapa1: imagine bruta');
xlabel('dimensiune in pixeli');

% imagine preprocesata (e2)
subplot(1, 2, 2);
imshow(imgFinala, [limitaInf limitaSup]);
colormap(gca, 'jet'); % aplicam culori pentru a distinge densitatile
colorbar;
title('etapa2: unitati HU (Filtru Muschi)');
xlabel('dimensiune in pixeli');

fprintf('--- REZULTATE ETAPA 2 ---\n');
fprintf('conversia HU si filtrarea au fost aplicate cu succes\n');

% etapa 3: metoda grafica - se cauta unde este L3
numarFelii = length(fisiere); %numara fisierele dicom
semnalOs = zeros(numarFelii, 1); %creeaza un tabel gol pt densitate

% scaneaza rapid densitatea centrala in toate feliile
fprintf('se genereaza profilul grafic al coloanei\n');
for i = 1:numarFelii
    numeFisier = fullfile(caleDate, fisiere(i).name); %construieste adresa completa a pozei curente
    imgTmp = double(dicomread(numeFisier)); %citeste poza
    
    % se ia prin aproximare doar un patrat central
    % asta elimina restul zgomotului din abdomen
    [R, C] = size(imgTmp); %afla dimensiunea imaginii
    zonaCentrala = imgTmp(round(R*0.55):round(R*0.75), round(C*0.45):round(C*0.55));
    
    % se calculeaza media intensitatii in zona coloanei
    semnalOs(i) = mean(zonaCentrala(:)); %calculeaza media pixelilor
end

% reprezentarea grafica a „senzorului de os"
figure('Name', 'analiza grafica - coloana vertebrala', 'NumberTitle', 'off');

subplot(2, 1, 1);
plot(semnalOs, 'LineWidth', 2, 'Color', 'b');
grid on;
title('profilul de densitate pe axa Z (Feliile CT)');
xlabel('numar felie');
ylabel('intensitate medie os');
hold on;

% gasim varful care corespunde L3
[valoareMax, idxL3_grafic] = max(semnalOs);
%valoare Max - scorul
% idxL3_grafic - numarul paginii unde s a gasit maximul
plot(idxL3_grafic, valoareMax, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
text(idxL3_grafic + 5, valoareMax, ['L3 detectat (felie: ', num2str(idxL3_grafic), ')']);

% afisam vizual felia gasita grafic
subplot(2, 1, 2);
numeFisierL3 = fullfile(caleDate, fisiere(idxL3_grafic).name);
imgL3 = double(dicomread(numeFisierL3));
imshow(imgL3, []);
title(['vizualizare felie L3: ', num2str(idxL3_grafic)]);

% rezultate
fprintf('--- REZULTATE ETAPA 3 ---\n');
fprintf('algoritmul de scanare axiala a finalizat analiza celor %d felii.\n', numarFelii);
fprintf('nivelul vertebral L3 a fost identificat la indexul: %d\n', idxL3_grafic);
fprintf('intensitatea medie de referinta (os): %.2f unitati brute\n', valoareMax);

% etapa 4: segmentarea muschiului scheletic pe L3
% preluam imaginea HU de la felia anterioara
% se ia vertebra L3 si se converteste in unitati Hu 
infoL3 = dicominfo(fullfile(caleDate, fisiere(idxL3_grafic).name));
imgL3_Raw = double(dicomread(infoL3));
imgL3_HU = imgL3_Raw * infoL3.RescaleSlope + infoL3.RescaleIntercept;

% crearea mastii binare - segmentare
% definim limitele standard pentru muschi: [-29, 150] HU
%verifica fiecare pixel din imagine
mascaMuschi = (imgL3_HU >= -29) & (imgL3_HU <= 150);

% rafinarea mastii - eliminarea obiectelor mici
% 'bwareaopen' sterge grupurile de pixeli mai mici de 500 (organe, vase sange)
mascaCurata = bwareaopen(mascaMuschi, 200);

% se elimina organele centrale
% se creeaza un cerc in centru pentru a exclude organele
[R, C] = size(mascaCurata);
[X, Y] = meshgrid(1:C, 1:R);

% definim centru si raza care ss acopere organele
centruX = C/2; centruY = R/2;
mascaCentrala = ((X - centruX).^2 / (C/4.5)^2 + (Y - centruY).^2 / (R/4.5)^2) < 1;
% se stergee ce e in centru (unde sunt de obicei intestinele)
mascaCurata(mascaCentrala) = 0;

% se pastreaza doar componentele mari
stats = regionprops(mascaCurata, 'Area', 'PixelIdxList');
[~, indiciiSortati] = sort([stats.Area], 'descend');

%se elimina muschii mari
mascaAutomata = false(size(mascaCurata));
numarComponenteDePastrat = min(5, length(stats)); 
for k = 1:numarComponenteDePastrat
    mascaAutomata(stats(indiciiSortati(k)).PixelIdxList) = true;
end

% umplerea gaurilor mici din interiorul muschilor
%umple pixelii negri din interiorul muschilor
mascaFinala = imfill(mascaAutomata, 'holes');

% vizualizarea rezultatului segmentarii
figure('Name', 'etapa 4: segmentare muschi L3', 'NumberTitle', 'off');

subplot(1, 2, 1);
imshow(imgL3_HU, [limitaInf limitaSup]);
title('felia L3 originala (HU)');

subplot(1, 2, 2);
% suprapunem masca peste img originala pentru control vizual
imshow(labeloverlay(uint8(imgL3_HU), mascaFinala, 'Colormap', 'spring'));
title('masca musculara segmentata');

fprintf('--- REZULTATE ETAPA 4 ---\n');
fprintf('segmentarea pe felia %d a fost finalizata\n', idxL3_grafic);
fprintf('Masca binară a izolat zonele cu densitate [-29, 150] HU\n\n');

% etapa 5: calculul smi si diagnosticul automat
% parametri de intrare - se introduce inaltimea in m
h = input('introdu inaltimea pacientului (in metri): ');
gen = input('introdu genul pacientului (m-masculin, f-feminin):', 's');

% calculul suprafetei musculare (SMA)
numarPixeliMuschi = sum(mascaFinala(:)); %numara pixelii albi - muschi
rezolutiePixel = infoL3.PixelSpacing; %pixelspacing - pixeli in mm
ariaPixel_mm2 = rezolutiePixel(1) * rezolutiePixel(2);
SMA_cm2 = (numarPixeliMuschi * ariaPixel_mm2) / 100; %aria digitala -> arie fizica

% calculul indicelui de sarcopenie - smi
SMI = SMA_cm2 / (h^2);

% logica de diagnostic 
if gen == 'm'  
    pragSarcopenie = 52.4; 
    genText = 'masculin';
else
    pragSarcopenie = 38.5; 
    genText = 'feminin';
end

if SMI < pragSarcopenie
    statusH = 'sarcopenie detectata';
    culoareText = 'red';
else
    statusH = 'masa musculara normala';
    culoareText = 'green';
end

fprintf('\n--- RAPORT FINAL EVALUARE SARCOPENIE ---\n');
fprintf('pacient: %s\n', info.PatientName.FamilyName);
fprintf('aria musculara (SMA): %.2f cm^2\n', SMA_cm2);
fprintf('indice muscular (SMI): %.2f cm^2/m^2\n', SMI);
fprintf('diagnostic: %s\n', statusH);
fprintf('---------------------------------------\n');

% vizualizare grafica pt diagnostic
figure('Name', 'rezultat diagnostic sarcopenie', 'NumberTitle', 'off');
imshow(labeloverlay(uint8(imgL3_HU), mascaFinala, 'Colormap', 'winter'));
hold on;

% afisam datele pe imagine
text(20, 30, ['SMA: ', num2str(round(SMA_cm2, 2)), ' cm^2'], 'Color', 'yellow', 'FontSize', 12, 'FontWeight', 'bold');
text(20, 60, ['SMI: ', num2str(round(SMI, 2)), ' cm^2/m^2'], 'Color', 'yellow', 'FontSize', 12, 'FontWeight', 'bold');
text(20, 90, statusH, 'Color', culoareText, 'FontSize', 14, 'FontWeight', 'bold', 'BackgroundColor', 'black');

title(['analiza sarcopenie - Pacient: ', info.PatientName.FamilyName]);