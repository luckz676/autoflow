require 'sinatra'
require 'sqlite3'
require 'time'
require 'uri'

set :public_folder, File.join(File.dirname(__FILE__), 'public')
set :views, File.join(File.dirname(__FILE__), 'views')
set :method_override, true
set :erb, trim: '>'

# Database path - configurable via ENV for deployment (Fly.io volume mount)
DB_PATH = ENV.fetch('DATABASE_PATH', File.join(File.dirname(__FILE__), 'db', 'garagem.db'))

def db_connection
  db = SQLite3::Database.new(DB_PATH)
  db.results_as_hash = true
  db
end

db_connection.execute <<-SQL
  CREATE TABLE IF NOT EXISTS veiculos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    marca TEXT NOT NULL,
    modelo TEXT NOT NULL,
    ano INTEGER NOT NULL,
    placa TEXT NOT NULL UNIQUE,
    quilometragem INTEGER DEFAULT 0,
    cor TEXT,
    tipo TEXT,
    status TEXT NOT NULL DEFAULT 'Disponível',
    proprietario TEXT,
    observacoes TEXT,
    criado_em DATETIME DEFAULT CURRENT_TIMESTAMP
  );
SQL

helpers do
  def formatar_data(data_str)
    return '' unless data_str
    Time.parse(data_str).strftime('%d/%m/%Y %H:%M')
  rescue ArgumentError
    data_str
  end

  def esc(value)
    Rack::Utils.escape_html(value.to_s)
  end

  def sucesso_mensagem
    {
      'criado' => 'Veículo adicionado à garagem.',
      'atualizado' => 'Dados do veículo atualizados.',
      'excluido' => 'Veículo removido da garagem.'
    }[params[:sucesso]]
  end
end

get '/' do
  redirect '/veiculos'
end

get '/veiculos' do
  db = db_connection
  @busca = params[:busca].to_s.strip
  @status = params[:status].to_s.strip

  sql = 'SELECT * FROM veiculos WHERE 1=1'
  binds = []

  unless @busca.empty?
    termo = "%#{@busca}%"
    sql << ' AND (marca LIKE ? OR modelo LIKE ? OR placa LIKE ? OR proprietario LIKE ?)'
    binds.concat([termo, termo, termo, termo])
  end

  unless @status.empty?
    sql << ' AND status = ?'
    binds << @status
  end

  sql << ' ORDER BY id DESC'
  @veiculos = db.execute(sql, binds)
  @total = db.get_first_value('SELECT COUNT(*) FROM veiculos').to_i
  @disponiveis = db.get_first_value("SELECT COUNT(*) FROM veiculos WHERE status = 'Disponível'").to_i
  @manutencao = db.get_first_value("SELECT COUNT(*) FROM veiculos WHERE status = 'Em manutenção'").to_i
  @vendidos = db.get_first_value("SELECT COUNT(*) FROM veiculos WHERE status = 'Vendido'").to_i
  @mensagem = sucesso_mensagem
  erb :index
end

get '/veiculos/novo' do
  @veiculo = {
    'quilometragem' => 0,
    'status' => 'Disponível',
    'tipo' => 'Carro'
  }
  erb :novo
end

post '/veiculos' do
  campos = %w[marca modelo ano placa quilometragem cor tipo status proprietario observacoes]
  v = campos.each_with_object({}) { |campo, h| h[campo] = params[campo].to_s.strip }
  v['placa'] = v['placa'].upcase
  erros = []
  erros << 'Informe a marca.' if v['marca'].empty?
  erros << 'Informe o modelo.' if v['modelo'].empty?
  erros << 'Informe um ano válido.' unless v['ano'].match?(/\A\d{4}\z/) && v['ano'].to_i.between?(1900, 2200)
  erros << 'Informe a placa.' if v['placa'].empty?
  erros << 'A quilometragem deve ser um número maior ou igual a zero.' unless v['quilometragem'].match?(/\A\d+\z/)

  if erros.any?
    @erros = erros
    @veiculo = v
    return erb :novo
  end

  begin
    db_connection.execute(
      'INSERT INTO veiculos (marca, modelo, ano, placa, quilometragem, cor, tipo, status, proprietario, observacoes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [v['marca'], v['modelo'], v['ano'].to_i, v['placa'], v['quilometragem'].to_i, v['cor'], v['tipo'], v['status'], v['proprietario'], v['observacoes']]
    )
    redirect '/veiculos?sucesso=criado'
  rescue SQLite3::ConstraintException
    @erros = ['Esta placa já está cadastrada.']
    @veiculo = v
    erb :novo
  end
end

get '/veiculos/:id' do
  @veiculo = db_connection.execute('SELECT * FROM veiculos WHERE id = ?', params[:id]).first
  halt 404, erb(:nao_encontrado) unless @veiculo
  erb :mostrar
end

get '/veiculos/:id/editar' do
  @veiculo = db_connection.execute('SELECT * FROM veiculos WHERE id = ?', params[:id]).first
  halt 404, erb(:nao_encontrado) unless @veiculo
  erb :editar
end

put '/veiculos/:id' do
  db = db_connection
  atual = db.execute('SELECT * FROM veiculos WHERE id = ?', params[:id]).first
  halt 404, erb(:nao_encontrado) unless atual

  campos = %w[marca modelo ano placa quilometragem cor tipo status proprietario observacoes]
  v = campos.each_with_object({}) { |campo, h| h[campo] = params[campo].to_s.strip }
  v['placa'] = v['placa'].upcase
  erros = []
  erros << 'Informe a marca.' if v['marca'].empty?
  erros << 'Informe o modelo.' if v['modelo'].empty?
  erros << 'Informe um ano válido.' unless v['ano'].match?(/\A\d{4}\z/) && v['ano'].to_i.between?(1900, 2200)
  erros << 'Informe a placa.' if v['placa'].empty?
  erros << 'A quilometragem deve ser um número maior ou igual a zero.' unless v['quilometragem'].match?(/\A\d+\z/)

  if erros.any?
    @erros = erros
    @veiculo = atual.merge(v)
    return erb :editar
  end

  begin
    db.execute(
      'UPDATE veiculos SET marca = ?, modelo = ?, ano = ?, placa = ?, quilometragem = ?, cor = ?, tipo = ?, status = ?, proprietario = ?, observacoes = ? WHERE id = ?',
      [v['marca'], v['modelo'], v['ano'].to_i, v['placa'], v['quilometragem'].to_i, v['cor'], v['tipo'], v['status'], v['proprietario'], v['observacoes'], params[:id]]
    )
    redirect '/veiculos?sucesso=atualizado'
  rescue SQLite3::ConstraintException
    @erros = ['Esta placa já está sendo usada por outro veículo.']
    @veiculo = atual.merge(v)
    erb :editar
  end
end

delete '/veiculos/:id' do
  db_connection.execute('DELETE FROM veiculos WHERE id = ?', params[:id])
  redirect '/veiculos?sucesso=excluido'
end
