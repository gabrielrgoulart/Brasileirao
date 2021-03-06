rodadas = 33
type = 'bayes.glm'
source("simulacao.R")
source("simplot.R")
# SETUP LIBRARIES -----
library("reshape")
library("reshape2")
library("ggplot2")
library(gsheet)
library(plyr)
library(e1071)
library(cowplot)
library(party)
library(tree)
library(rpart)
library(rpart.plot)
library(partykit)
library(arm)
library(gridExtra)
library(neuralnet)
library("balamuta")
library(stringr)
library(gbm)
library(adabag)

# SOURCES ------
source("expected.R")
source("xGtimes.R")
source("tabela.R")
source("br16.R")
source("br15.R")
source("jogadores.R")
source("jogobtm.R")
source("simulacao.R")
source("teamratingbtm.R")
source("simulacaobtm.R")
source("correlacao.R")
source("setupxG.R")
source("setupxgbr.R")
source("simulacaoxG.R")
source("boxsim.R")
source("jogoxG.R")
source("jogopoisson.R")
source("minutos.R")
source("probabilidades.R")
source("projecaopontos.R")
source("modeloPdG.R")
source('simplot.R')
source('mapacalor.R')

# SETUP xG ------

##VARIAVEIS
threshold = 0.3

xG = setup.xG(rodadas)
xG.chutes = xG$xG.chutes
xG = xG$xG
times = levels(xG$Time)

# glm bad --------

#SEM REGIAO

model = glm(Gol~.,data=xG[ , (names(xG) %in% c('Gol','Cruzamento.Cruz..rasteiro',
                                               'Passe.Profundo','Contra.ataque',
                                               'Erro.da.zaga',
                                               'Perigo.de.gol'))],
            family = binomial(link = 'probit'))
summary(model)
#COM REGIAO
model = glm(Gol~.,data=xG.new[ , !(names(xG) %in% c('Rodada','Regiao.ASS','Jogador','Jogador.ASS','Time','Adversario'))],family = binomial(link = 'probit'))
summary(model)

campeonato = xGtimes(dados = xG.chutes, model = model, rodadas = rodadas, threshold = threshold, rpart = NULL)



#

# bayes glm -----
source('xGtimes.R')
xG.chutes$RegiaoChute = paste( as.character(xG.chutes$Regiao) ,
                                           as.character(xG.chutes$Tipo.de.chute)  )
# xG.chutes$RegiaoChute = as.factor(xG.chutes$RegiaoChute)
# bayes.xG=bayesglm(Gol~ Cruzamento.Cruz..rasteiro+Passe.Profundo+
#                     Contra.ataque+Erro.da.zaga+Em.Casa+Regiao.ASS+
#                     RegiaoChute +Tipo.de.Jogada,
#                   data=xG.chutes[ , (names(xG.chutes) %in% c('Gol',
#                                                             'Cruzamento.Cruz..rasteiro',
#                                                             'Passe.Profundo','Contra.ataque',
#                                                             'Erro.da.zaga','Em.Casa','Tipo.de.chute',
#                                                           'Regiao.ASS','Regiao','Tipo.de.Jogada',
#                                                           'RegiaoChute'))],
#                   family=binomial, drop.unused.levels = F )
bayes.xG=bayesglm(Gol~ .,
                  data=xG.chutes[ , (names(xG.chutes) %in% c('Gol',
                                                            'Cruzamento.Cruz..rasteiro',
                                                            'Passe.Profundo','Contra.ataque',
                                                            'Erro.da.zaga','Em.Casa','Tipo.de.chute',
                                                          'Regiao.ASS','Regiao','Tipo.de.Jogada'
                                                         ))],
                  family=binomial, drop.unused.levels = F )

#models = projecao.gol(rodadas = rodadas, type = 'bayes.glm', peso = 0)
model = bayes.xG
source('xGtimes.R')
campeonato = xGtimes(dados = xG.chutes, model = model, rodadas = 19, 
                     rodada.inicial = 1,threshold = threshold, 
                     type = 'bayes.glm', momentum = 5, peso = 0)
campeonato$xG.plot
campeonato$xGC.plot
campeonato$xSG
campeonato$xG.data

## Naive Bayes -----
naive=naiveBayes(Gol~.,data=xG.chutes[ , (names(xG.chutes) %in% c('Gol',
                                                                   'Cruzamento.Cruz..rasteiro',
                                                                   'Passe.Profundo','Contra.ataque',
                                                                   'Erro.da.zaga','Em.Casa',
                                                                   'Regiao.ASS','Regiao','Tipo.de.Jogada'))],
                  family=binomial, drop.unused.levels = F )


model = naive
b = predict(model,xG.chutes, type = 'raw')
source('xGtimes.R')
campeonato = xGtimes(dados = xG.chutes, model = model, rodadas = rodadas, 
                     rodada.inicial = 1,threshold = threshold, 
                     type = 'naive', momentum = 0, peso = .65)
campeonato$xG.plot
campeonato$xGC.plot

## GBM -----
gbm.gol=gbm(Gol~.,data=xG.chutes[ , (names(xG.chutes) %in% c('Gol',
                                                                  'Cruzamento.Cruz..rasteiro',
                                                                  'Passe.Profundo','Contra.ataque',
                                                                  'Erro.da.zaga','Em.Casa',
                                                                  'Regiao.ASS','Regiao','Tipo.de.Jogada'))],
          distribution = "adaboost", n.trees = 5000) 


model = gbm.gol
prediction = predict(model, xG.chutes, n.trees = 5000, type = 'response')

campeonato = xGtimes(dados = xG.chutes, model = model, rodadas = rodadas, 
                     rodada.inicial = 1,threshold = threshold, 
                     type = 'gbm', momentum = 0, peso = .65)
campeonato$xG.plot
campeonato$xGC.plot

## Neural Network -------
m <- model.matrix( 
  ~ Gol + Cruzamento.Cruz..rasteiro + Passe.Profundo + Regiao + Regiao.ASS +
    Contra.ataque + Erro.da.zaga + Em.Casa + Regiao + Tipo.de.Jogada, 
  data = xG.chutes
)
colnames(m)[66] <- "Tipo.de.JogadaFaltaDireta"
colnames(m)[67] <- "Tipo.de.JogadaFaltaIndireta"

n <- colnames(m)
n = n[2:length(n)]

f <- as.formula(paste("Gol1 ~", paste(n[!n %in% "Gol1"], collapse = " + ")))
nn <- neuralnet(f,data=m,hidden=35,linear.output=F,
                stepmax=1e6, algorithm = 'backprop', learningrate = 0.01)

model = nn
campeonato = xGtimes(dados = xG.chutes, model = model, rodadas = rodadas, threshold = threshold, type = 'neuralnetwork')
campeonato$xG.plot

## Boruta ------

b=Boruta(xG.chutes[ , (names(xG.chutes)[3:ncol(xG.chutes)])], xG.chutes$Gol)

# tree ------
# tree.xG <- ctree(Gol~.,data=xG[ , (names(xG) %in% c('Gol',
#                                                     'Cruzamento.Cruz..rasteiro',
#                                                     'Passe.Profundo','Contra.ataque',
#                                                     'Erro.da.zaga','Em.Casa',
#                                                     'Perigo.de.gol','Regiao','Saldo','Tipo.de.Jogada'))])
# plot(tree.xG)

rpart.xG=rpart(Gol~.,data=xG[ , (names(xG) %in% c('Gol', 'Regiao',
                                                  'Cruzamento.Cruz..rasteiro',
                                                  'Passe.Profundo','Contra.ataque',
                                                  'Erro.da.zaga','Em.Casa',
                                                  'Perigo.de.gol','Regiao','Saldo','Tipo.de.Jogada'))])
model = rpart.xG
campeonato = xGtimes(dados = xG.chutes, model = model, rodadas = rodadas, threshold = threshold, type = 'rpart')

# xG Plot e Data ------
campeonato = xGtimes(dados = xG.chutes, model = model, rodadas = rodadas, rodada.inicial = 1,
                     threshold = threshold, type = 'bayes.glm')
campeonato$xG.data
campeonato$xG.plot
campeonato$xGC.plot
campeonato$Todos.Times
campeonato$xSG
campeonato$em.casa
campeonato$fora.de.casa
campeonato$xSG.casa
campeonato$xSG.fora
campeonato$xG.ratio
campeonato$xG.ratio.Casa
campeonato$xG.ratio.Fora
campeonato$xG.ratio.mando

png("AxGC.png", width = 6.5, height = 8, units = 'in', res = 500)
plot(campeonato$xGC.plot) # Make plot
dev.off()

# xG Jogadores -----
source('jogadores.R')

players = jogadores(dados = xG.chutes, model = model, rodadas = rodadas, threshold = threshold, 
                    type = 'bayes.glm', njogadores =20)
players$xG.chute

players$Finalizadores.jogo
players$Finalizadores.chute
players$xG.gol
players$xG.chute
players$Passadores
players$Passadores.chance.boa
players$Passadores.chance.aprov
players$Participacao

xgplayers = players$best.players
xaplayers = players$best.pass

png("APlot3.png", width = 7.5, height = 7.5, units = 'in', res = 500)
plot(players$xG.chute) # Make plot
dev.off()

png("xGplayers.png", width = 7, height = 8, units = 'in', res = 500)
plot(players$Finalizadores.jogo) # Make plot
dev.off()

png("xA.png", width = 7, height = 8, units = 'in', res = 500)
plot(players$Passadores) # Make plot
dev.off()

# campeonato e relacao xG -----
bra16 = br16(rodadas = 33, rodada.inicial = 20)
campeonato = xGtimes(dados = xG.chutes, model = model, rodadas = 33, 
                     rodada.inicial = 20,threshold = threshold, type = 'bayes.glm', momentum = 0, 
                     peso = 0)

source('correlacao.R')

graficos.xG = correlacao(xG.campeonato = campeonato, tabela = bra16)
graficos.xG$xG
graficos.xG$xGC
graficos.xG$xSG
graficos.xG$xGxGC
graficos.xG$xG.ratio
graficos.xG$xG.pontos
graficos.xG$chutes.gols
graficos.xG$chutes.golsC
png("Plot3.png", width = 7.5, height = 7.5, units = 'in', res = 500)
plot(graficos.xG$xG) # Make plot
dev.off()

png("AchutesC.png", width = 8, height = 7, units = 'in', res = 500)
plot(Chutes.golsC) # Make plot
dev.off()

# BRASIL -----
threshold = 0.3
source("setupxgbr.R")

xG.br = setup.xG.Brasil()
xG.br = xG.br$xG.chutes
times = levels(xG$Time)

casa = c('Equador')
gj.xG = 0
gj.xA = 0
pc.xG = 0
pc.xA = 0
jesus = data.frame(Adv = rep(c('Ecuador','Colombia','Bolivia','Venezuela'),2),
                   value = c(gj.xG,gj.xA),
                   tipo = c(rep('xG',4),rep('xGC',4)))
                   
for (i in 1:4){
  bibi = xG.br[xG.br$Jogador == 'Philippe Coutinho' & xG.br$Rodada == i ,]
  pc.xG[i] = sum(predict(model,bibi,type="response"))
  bibi = xG.br[xG.br$Jogador.ASS == 'Philippe Coutinho' & xG.br$Rodada == i ,]
  if (nrow(bibi) == 0){
    pc.xA[i] = 0
  } else{
    pc.xA[i] = sum(predict(model,bibi,type="response"))
  }
}


ggplot(data = jesus, aes(x = factor(Adv,levels=unique(Adv)), y = value, group = tipo, colour = tipo),
       size = 1.8, alpha = 0.85)+
  geom_line()+
  xlab('')+
  ylab('')+
  theme_classic()+
  theme(
        text=element_text(family="Avenir"),
        axis.line.y = element_line(
          colour = "gray26"),
        axis.line.x = element_line(
          colour = "white"),
        axis.ticks.y = element_line(color="gray26"),
        axis.text.x = element_text(size = 12, color = 'gray26'),
        axis.text.y = element_text(size = 12, color = 'gray26'),
        axis.title.y=element_text(size=12, color = 'gray26'),
        axis.title.x=element_text(size=12, color = 'gray26'),
        legend.title = element_text(color = 'white'),
        panel.grid.major = element_line(colour = "gray26",size = .03),
        panel.grid.minor = element_line(colour = "gray26",
                                        linetype = 'dashed',size = .045))+

jogoxG = jogo.xG(data = xG.br, model = model, rodada = 2, 
                 casa = 'Brasil', type = 'bayes.glm', tempo = T)
jogoxG$plots.tempo

png("Colombia.png", width = 8, height = 7, units = 'in', res = 400)
plot(jogoxG$plots.tempo[[1]])# Make plot
dev.off()

# MAPA CALOR -----
mapa = mapa.de.calor(xG.chtues)
mapa

# JOGO XG ------
bra16 = br16(rodadas = rodadas)
casa = bra16$jogos[bra16$jogos$Rodada == rodadas,]
casa = as.character(casa$Casa)

casa = c('Palmeiras')
jogoxG = jogo.xG(data = xG.chutes, model = model, rodada = 32, 
                 casa = casa, type = 'bayes.glm', tempo = TRUE)
jogoxG$plots.tempo

if (jogoxG$njogos > 1){
  b1 = do.call("plot_grid", c(jogoxG$plots.tempo, nrow = 5, align = 'v'))
  g1 <- arrangeGrob(b1,
                    bottom = textGrob('@ProjecaoDeGol - Pontos representam gols', x = 0, hjust = -0.1, vjust=0.1, gp = gpar(col = 'gray26',fontfamily = 'Avenir Next Condensed',fontface = "italic", fontsize = 12)),
                    top = textGrob('Evolução de xG dos jogos da 26ª rodada',
                                   gp = gpar(fontfamily = 'Avenir Next Condensed',col = 'gray26',fontsize = 18)))
  grid.draw(g1)
} else{
  b = jogoxG$plots[[1]]
  g = ggplotGrob(b)
  g <- arrangeGrob(b,
      bottom = textGrob('@ProjecaoDeGol', x = 0, hjust = -0.1, vjust=0.1, gp = gpar(fontface = "italic", fontsize = 12)))
  grid.draw(g)
}

png("Plot3.png", width = 9.5, height = 19.5, units = 'in', res = 400)
grid.draw(g1)# Make plot
dev.off()
jogoxG$plots.tempo
png("APlot3.png", width = 8, height = 7, units = 'in', res = 400)
plot(jogoxG$plots.tempo[[1]])# Make plot
dev.off()
#

# JOGO POISSON ----
bra16 = br16(rodadas = 28)
casa = bra16$jogos[bra16$jogos$Rodada == rodadas,]
casa = as.character(casa$Casa)
fora = bra16$jogos[bra16$jogos$Rodada == rodadas,]
fora = as.character(fora$Fora)


source('modeloPdG.R')
rodadas = 31

models = projecao.gol(rodadas = 32, type = 'bayes.glm', peso = .5, casa = F)


casa = c('Palmeiras','Atlético MG','Ponte Preta','Fluminense','São Paulo','Grêmio')
fora = c('Cruzeiro','América','Vitória','Flamengo','Santos','Atlético PR')
source('jogopoisson.R')
jogopoisson = poisson.pred(rodadas = (rodadas-1), casa = casa, fora = fora,
                           models = models, type = 'bayes.glm',
                           momentum = 5, peso = .6)

jogopoisson$probs

  b1 = do.call("plot_grid", c(jogopoisson$plots, nrow = 5, align = 'v'))
  g1 <- arrangeGrob(b1,
                    bottom = textGrob('@ProjecaoDeGol', x = 0, hjust = -0.1, vjust=0.1, gp = gpar(col = 'gray26',fontfamily = 'Avenir Next Condensed',fontface = "italic", fontsize = 12)),
                    top = textGrob('Projeções de gol para 27ª rodada',
                                   gp = gpar(fontfamily = 'Avenir Next Condensed',col = 'gray26', fontsize = 17)))
  grid.draw(g1)



png("APlot3.png", width = 8, height = 12, units = 'in', res = 400)
grid.draw(jogopoisson$plots[[4]])# Make plot
dev.off()
#

# PROJECAO PONTOS -------
#ajustar desvio padrão
projecao = projecao.pontos(rodadas = rodadas, type = 'bayes.glm', momentum = 6,
                           peso.m = .4, peso.btm = .3, lm.Gol.Casa = models$Casa,
                           lm.Gol.Fora = models$Fora, model = models$model,nsim=50000,
                           sd = 4.2)

plotsim = plot.sim(rodadas = rodadas, nsimulacoes = 50000, 
                   peso.btm = 0, 
                   sim.btm16 = projecao, sim.xG =projecao)
plotsim$Box
plotsim$Mapa
plotsim$Campeoes
plotsim$Box
plotsim$G4
plotsim$Z4
plotsim$posicoes
plotsim$pontos

# BTM MODEL -------
bra15 = br15(rodadas = 27)
rank.btm15 = team.rating.btm(jogos = bra15$jogos, rodadas = 27, 
                             resultados.casa = bra15$resultados.casa,
                             momentum = 5, peso = 0.06)

rank.btm15$Ranking.Plot
rank.btm15$Ranking

rank.btm15$Ranking.Plot.Momento
rank.btm15$Ranking.Momento

bra16 = br16(rodadas = rodadas)
rank.btm16 = team.rating.btm(jogos = bra16$jogos, rodadas = rodadas, 
                           resultados.casa = bra16$resultados.casa,
                           momentum = 5, peso = .65)
rank.btm16$Ranking.Plot.Momento

#0.07 0.25 0.2

rank.btm16$Ranking
rank.btm16$Ranking.Plot
##MOMENTOOO!!!!!
rank.btm16$Ranking.Plot.Momento
rank.btm16$Ranking.Momento

png("Plot3.png", width = 6, height = 5, units = 'in', res = 300)
plot(rank.btm16$Ranking.Plot.Momento) # Make plot
dev.off()

# SIMULACAO BTM -----
sim.btm15 = simulacao.btm(rating = rank.btm15,
                      nsimulacoes = 1000,regressao = F, momentum = TRUE)
sim.btm15$Mapa
sim.btm15$Pontos

sim.btm16 = simulacao.btm(rating = rank.btm16, 
                             nsimulacoes = 3000,regressao = FALSE,
                      momentum = TRUE)
                     
sim.btm16$Mapa
sim.btm16$Pontos
sim.btm16$Pontos.Plot
sim.btm16$Campeoes
sim.btm16$Posicoes
sim.btm16$df.pontos
sim.btm16$df.campeoes
sim.btm16$Box
sim.btm16$matriz.pontos


png("Plot3.png", width = 6, height = 4, units = 'in', res = 300)
plot(sim.btm16$Mapa) # Make plot
dev.off()

png("Plot3.png", width = 6, height = 4, units = 'in', res = 300)
plot(sim.btm16$Campeoes) # Make plot
dev.off()

# SIMULACAO XG --------

sim.xG = simulacao.xG(rodadas = 26, nsimulacoes = 10, 
                      type = 'bayes.glm', momentum = 7, peso = 0, models = models)
sim.xG$Mapa
sim.xG$Pontos
sim.xG$Pontos.Plot
sim.xG$Campeoes
sim.xG$Posicoes
sim.xG$Box

ggplot(as.data.frame(table(sim.xG$Pontos)), 
       aes(x=Equipes, y = Pts, fill = Pts)) + geom_bar(stat="identity")

ggplot(sim.xG$Pontos, aes(x=reorder(Equipes,Pts),y=Pts 
                    ))+
  geom_boxplot()+
  coord_flip()+
  scale_fill_gradient(low="gray16",high="steelblue1")+
  ylab("Coeficiente de Forca")+xlab("")+
  ggtitle("Ranking de Forca dos Times")+
  theme(legend.position="none")

# BOX XG BTM -----
box.mix = box.sim(rodadas= 20, peso.btm = .12, btm = sim.btm16$df.pontos, xG = sim.xG$df.pontos)
box.mix
box.mix

png("Plot3.png", width = 8, height = 6, units = 'in', res = 300)
plot(box.mix) # Make plot
dev.off()

# SIMULACAO -----
source('simplot.R')
sim = simulacao(rodadas = rodadas, nsimulacoes = 7000, 
                m.btm = 6, m.xG = 6,
                peso.momentum = .5, type= 'bayes.glm', models = models)

sim50 = sim
plotsim = sim.plot(rodadas = rodadas, nsimulacoes = 7000, 
         peso.btm = 0, 
         sim.btm16 = sim$sim.btm16, sim.xG = sim$sim.xG)
plotsim$Box
plotsim$Mapa
plotsim$Campeoes
plotsim$Box
plotsim$G4
plotsim$Z4
plotsim$posicoes
plotsim$pontos

png("APlot3.png", width = 7, height = 8, units = 'in', res = 450)
plot(plotsim$G4) # Make plot
dev.off()

png("APlot3.png", width = 7, height = 8.5, units = 'in', res = 450)
plot(plotsim$Box) # Make plot
dev.off()

png("APlot3.png", width = 7.5, height = 6.5, units = 'in', res = 450)
plot(plotsim$Campeoes) # Make plot
dev.off()

png("APlot3.png", width = 6.5, height = 8.5, units = 'in', res = 450)
plot(campeonato$xG.plot) # Make plot
dev.off()

