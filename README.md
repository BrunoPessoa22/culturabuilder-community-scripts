# 🦅 Cultura Builder - Community Scripts

Scripts e recursos criados pela comunidade Cultura Builder para facilitar o setup e manutenção de agentes de IA.

## 📁 Estrutura

```
├── scripts/
│   ├── install-openclaw-secure.sh    # Instalador seguro do OpenClaw
│   └── backup-openclaw.sh            # Backup completo do OpenClaw
├── docs/
│   └── GUIA-SEGURANCA-AGENTES-IA.md  # Guia de segurança completo
└── README.md
```

## 🚀 Scripts Disponíveis

### install-openclaw-secure.sh

Instalador completo do OpenClaw com todas as configurações de segurança.

**O que faz:**
- ✅ Atualiza o sistema
- ✅ Instala Node.js 20 LTS
- ✅ Configura Firewall (ufw)
- ✅ Configura Fail2ban
- ✅ Cria estrutura de pastas segura
- ✅ Instala OpenClaw
- ✅ Cria scripts auxiliares
- ✅ Adiciona aliases úteis

**Uso:**
```bash
curl -fsSL https://raw.githubusercontent.com/BrunoPessoa22/culturabuilder-community-scripts/main/scripts/install-openclaw-secure.sh | bash
```

Ou baixe e execute manualmente:
```bash
wget https://raw.githubusercontent.com/BrunoPessoa22/culturabuilder-community-scripts/main/scripts/install-openclaw-secure.sh
chmod +x install-openclaw-secure.sh
./install-openclaw-secure.sh
```

---

### backup-openclaw.sh

Script de backup completo com verificação de integridade.

**O que faz:**
- ✅ Para o OpenClaw com segurança
- ✅ Cria backup comprimido
- ✅ Verifica integridade
- ✅ Backup do .env (com criptografia opcional)
- ✅ Gera documentação
- ✅ Upload para S3 (opcional)

**Uso:**
```bash
wget https://raw.githubusercontent.com/BrunoPessoa22/culturabuilder-community-scripts/main/scripts/backup-openclaw.sh
chmod +x backup-openclaw.sh
./backup-openclaw.sh
```

Com upload para S3:
```bash
./backup-openclaw.sh --upload-s3 meu-bucket
```

---

## 📚 Documentação

### GUIA-SEGURANCA-AGENTES-IA.md

Guia completo de segurança para deploy de agentes de IA, incluindo:

- Preparação do ambiente Linux
- Instalação segura
- Configuração de credenciais
- Permissões e isolamento
- Monitoramento e logs
- Prevenção de problemas
- 🚨 **Procedimentos de emergência**
- Checklist de deploy
- Comunicação com cliente

[📖 Ler o guia completo](docs/GUIA-SEGURANCA-AGENTES-IA.md)

---

## 🤝 Contribuindo

Quer adicionar seu script ou documentação? 

1. Fork este repositório
2. Crie uma branch (`git checkout -b feature/meu-script`)
3. Commit suas mudanças (`git commit -m 'Adiciona meu script'`)
4. Push para a branch (`git push origin feature/meu-script`)
5. Abra um Pull Request

---

## 👥 Créditos

- **Águia** 🦅 — Agente de IA da Cultura Builder
- **Miqueias Ruben** — Contribuições em segurança
- **Comunidade CB** — Discussões e feedback

---

## 📞 Suporte

- **Comunidade:** [Cultura Builder](https://culturabuilder.com)
- **YouTube:** [@cultura-builder](https://youtube.com/@cultura-builder)

---

## 📜 Licença

MIT License - Sinta-se livre para usar e modificar!

---

*Criado com 🦅 pela comunidade Cultura Builder*
