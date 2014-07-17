function modify_check_box(o,d){
    if(o.checked){
        getCheckboxByValue(d).disabled = false;
    }else{
        getCheckboxByValue(d).disabled = true;
    }
}

function getCheckboxByValue(v) {
    var inputs = document.getElementsByTagName('input');
    for (var i = 0; i < inputs.length; i ++) {
        if (inputs[i].type == 'checkbox' && inputs[i].value == v) {
            return inputs[i];
        }
    }
    return false;
}

function check_box_disabled(o){
    if(o.checked){
        return false;
    }
    else{
        return true;
    }
}