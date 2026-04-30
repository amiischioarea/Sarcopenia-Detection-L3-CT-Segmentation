clear net lgraph ds ds_combined imdsResized pxdsResized
clc

% pregatim datele
[imds_raw, pxds_raw] = pixelLabelTrainingData(gTruth);

classNames = ["Background", "Muschi"];
pixelLabelID = uint8([0, 1]); 
targetSize = [512 832];

% conversie in celule pentru compatibilitate
%categorical - transorma masca intr o harta simpla
imdsResized = transform(imds_raw, @(x) {im2single(imresize(x, targetSize))});
pxdsResized = transform(pxds_raw, @(x) {categorical(uint8(imresize(x{1}, targetSize, 'nearest')), pixelLabelID, classNames)});

%creeaza un set de date unde fiecare data este legata de retea
ds = combine(imdsResized, pxdsResized);

% construim arhitectura U-NET
imageSize = [512 832 1]; 
numClasses = 2; 
lgraph = unetLayers(imageSize, numClasses);

% antrenarea 
options = trainingOptions('adam', ...
    'InitialLearnRate', 1e-3, ...
    'MaxEpochs', 60, ... 
    'MiniBatchSize', 4, ... 
    'Shuffle', 'every-epoch', ...
    'Plots', 'training-progress', ... % aceasta trebuie sa deschida fereastra
    'Verbose', true, ...             % va scrie detalii in cw
    'ExecutionEnvironment', 'auto'); 

fprintf('antrenarea porneste acum\n');

%comanda pt antrenare
net = trainNetwork(ds, lgraph, options);

save('ModelFinal_TEST_FUNCTIONAL.mat', 'net');