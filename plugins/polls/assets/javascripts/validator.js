$(".validar_form").submit(function ()
{
    var cont = 0;
    for (i = 0; ele = document.form.elements[i]; i++)
    {
        if (ele.type == 'radio')
            if (ele.checked)
            {
                cont = cont + 1;
            }
        if (ele.type == 'textarea')
            if (ele.value.length > 0)
            {
                cont = cont + 1;
            }
    }
    if (cont == document.getElementById('polls_count').value)
    {
        $.modal.close();
    }
    else {
        alert('Debe responder todas las preguntas, gracias.');
        return false;
    }
    return true;
});