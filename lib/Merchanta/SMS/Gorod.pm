# package Merchanta::SMS::Gorod;
# package Merchanta::SMS::Gorod::SMPP;
# package Merchanta::SMS::Gorod::XML;

package Merchanta::SMS::Gorod::HTTP 1.0;

use utf8;

use strict;
use warnings;

use URI;
use LWP::UserAgent;

use constant API_URL_NUMERIC      => 'http://web.smsgorod.ru/sendsms.php';
use constant API_URL_STANDARD     => 'http://web2.smsgorod.ru/sendsms.php';
use constant API_TIMEOUT_SEC      => 30;
use constant API_DEFAULT_FROM     => 'SMSGOROD.RU';
use constant API_USER_AGENT       => __PACKAGE__ . '/' . __PACKAGE__->VERSION;

use constant NO_ERROR             =>  1;
use constant ERROR_API            =>  0;
use constant ERROR_INVALID_USER   => -2;
use constant ERROR_BALANCE_RCPT   => -3;
use constant ERROR_RCPT           => -4;
use constant ERROR_RCPT_STOP      => -5;
use constant ERROR_NO_SENDER      => -6;
use constant ERROR_ACCOUNT_LOCKED => -7;
use constant ERROR_INVALID_SENDER => -8;
use constant ERROR_UNKNOWN        => -100;

use constant STATUS_ACCEPTED      =>   2;
use constant STATUS_DELIVERED     =>   3;
use constant STATUS_FAILED        => -23;
use constant STATUS_EXPIRED       => -24;
use constant STATUS_NOT_FOUND     => -25;
use constant STATUS_UNKNOWN       => -200;

use constant ERROR_MESSAGE_INVALID_USER     => 'Неверный логин или пароль';
use constant ERROR_MESSAGE_CHECK_BALANCE    => 'Проверьте свой баланс или корректность номера получателя.';
use constant ERROR_MESSAGE_NO_RCPT          => 'Укажите номер телефона.';
use constant ERROR_MESSAGE_INVALID_RCPT     => 'Не введен номер телефона.';
use constant ERROR_MESSAGE_RCPT_IN_STOPLIST => 'Номер телефона присутствует в стоп-листе.';
use constant ERROR_MESSAGE_SENDER_NOT_FOUND => 'Такого отправителя нет.';
use constant ERROR_MESSAGE_ACCOUNT_LOCKED   => 'Ваш аккаунт заблокирован.';
use constant ERROR_MESSAGE_INVALID_SENDER   => 'Отправитель не должен превышать 15 символов для цифровых номеров и 11 символов для буквенно-числовых.';

use constant STATUS_MESSAGE_ACCEPTED        => 'send';
use constant STATUS_MESSAGE_DELIVERED       => 'deliver';
use constant STATUS_MESSAGE_FAILED          => 'not_deliver';
use constant STATUS_MESSAGE_EXPIRED         => 'expired';
use constant STATUS_MESSAGE_NOT_FOUND       => 'Сообщение с таким ID не принималось';

sub new
{
	my ($class, %data) = @_;

	my $self = {

		'user'    => $data{'user'} || '',
		'pwd'     => $data{'pass'} || '',
		'from'    => $data{'from'} || API_DEFAULT_FROM,

		'numeric' => $data{'numeric'} ? 1 : 0,

		'agent'   => LWP::UserAgent->new(

			'agent'   => API_USER_AGENT,
			'timeout' => API_TIMEOUT_SEC,
		)
	};

	return bless $self, $class;
}

sub set_error
{
	my $self  = shift;
	my $error = shift;
	my $info  = shift;

	$self->{'error'}      = $error;
	$self->{'error_info'} = $info;

	return $error;
}

sub get_error
{
	my $self  = shift;

	return wantarray ? ( $self->{'error'}, $self->{'error_info'} ) : $self->{'error'};
}

sub has_error
{
	my $self  = shift;

	return $self->{'error'} ? 1 : 0;
}

sub __make_request
{
	my ($self, %data) = @_;

	$self->set_error(); # сбрасываем

	my $uri = URI->new( $self->{'numeric'} ? API_URL_NUMERIC : API_URL_STANDARD );

	$data{'user'} = $self->{'user'};
	$data{'pwd'}  = $self->{'pwd'};

	$uri->query_form(\%data);

	$self->{'response'} = $self->{'agent'}->get($uri->canonical);
}

sub send
{
	my ($self, $rcpt, $message) = @_;

	my $dadr = ('ARRAY' eq ref $rcpt) ? join(',', @$rcpt) : $rcpt;

	$self->__make_request('sadr' => $self->{'from'}, 'dadr' => $dadr, 'text' => $message);

	return $self->set_error(ERROR_API, $self->{'response'}->status_line) unless $self->{'response'}->is_success;

	my $content = $self->{'response'}->decoded_content;

	# TODO возврат индивидуальных ошибок/статуса для каждого номера
	# NOTE непонятно как там будут выдаваться ошибки если по одному нормеру всё хорошо, а по другому всё плохо

	# всё хорошо, получили id задания на отправку, его и вернём
	return wantarray ? (NO_ERROR, split(/,/, $content)) : NO_ERROR if $content =~ /^\d+(?:,\d+)*$/;

	my $error = ERROR_UNKNOWN;

	if    ( $content eq ERROR_MESSAGE_INVALID_USER     ) { $error = ERROR_INVALID_USER;   }
	elsif ( $content eq ERROR_MESSAGE_CHECK_BALANCE    ) { $error = ERROR_BALANCE_RCPT;   }
	elsif ( $content eq ERROR_MESSAGE_INVALID_RCPT     ) { $error = ERROR_RCPT;           }
	elsif ( $content eq ERROR_MESSAGE_NO_RCPT          ) { $error = ERROR_RCPT;           }
	elsif ( $content eq ERROR_MESSAGE_RCPT_IN_STOPLIST ) { $error = ERROR_RCPT_STOP;      }
	elsif ( $content eq ERROR_MESSAGE_SENDER_NOT_FOUND ) { $error = ERROR_NO_SENDER;      }
	elsif ( $content eq ERROR_MESSAGE_ACCOUNT_LOCKED   ) { $error = ERROR_ACCOUNT_LOCKED; }
	elsif ( $content eq ERROR_MESSAGE_INVALID_SENDER   ) { $error = ERROR_INVALID_SENDER; }

	return $self->set_error($error, $content);
}

sub get_status
{
	my ($self, $smsid) = @_;

	my $response = $self->__make_request('smsid' => $smsid); 

	unless ( $response->is_success )
	{
		return $self->set_error(ERROR_API);
	}

	my $content = $response->decoded_content;

	return STATUS_ACCEPTED  if $content eq STATUS_MESSAGE_ACCEPTED;
	return STATUS_DELIVERED if $content eq STATUS_MESSAGE_DELIVERED;

	my $status = STATUS_UNKNOWN;

	if    ( $content eq STATUS_MESSAGE_FAILED    ) { $status = STATUS_FAILED;    }
	elsif ( $content eq STATUS_MESSAGE_EXPIRED   ) { $status = STATUS_EXPIRED;   }
	elsif ( $content eq STATUS_MESSAGE_NOT_FOUND ) { $status = STATUS_NOT_FOUND; }

	return $self->set_error($status, $content);
}

1;
